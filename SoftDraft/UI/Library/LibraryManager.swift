//
//  LibraryManager.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Library/LibraryManager.swift

import Foundation
import Combine

@MainActor
final class LibraryManager: ObservableObject {

    enum StartupState {
        case resolving
        case noLibrary
        case loaded(URL)
    }
    
    let collectionsDir = "collections"

    @Published private(set) var activeLibraryURL: URL?
    @Published private(set) var startupState: StartupState = .resolving
    @Published private(set) var visibleNotes: [NoteSummary] = []
    @Published private(set) var visibleCollectionID: String?
    @Published private(set) var externalChangeTokens: [String: UUID] = [:]
    @Published private(set) var visibleCollections: [String] = []
    @Published private(set) var libraryIndex: LibraryIndex?
    
    @Published var currentNoteText: String = ""
    
    private var cancellables: Set<AnyCancellable> = []
    let mandatoryCollections: Set<String> = ["Inbox"]

    private weak var selection: SelectionModel?
    private var filesystemWatcher: LibraryFilesystemWatcher?
    private var internalWriteDepth = 0
    private var recentInternalWrites: [String: Date] = [:]
    private let internalWriteCooldown: TimeInterval = 1.0
    // Tracks whether we still need to restore the persisted selection for this library.
    private var needsInitialCollectionSelection = false
    private var boundSearchIndex: SearchIndex?
    private var isLibraryIndexDirty = false
    private var hasRunCatchUpReconciliation = false

    // MARK: - Startup

    func bind(selection: SelectionModel) {boundSearchIndex.map { rebuildSearchIndex($0) }
        self.selection = selection

        // Persist last active collection when selection changes
        selection.$selectedCollectionID
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] collectionID in
                guard
                    let self,
                    let libraryURL = self.activeLibraryURL
                else { return }

                Task {
                    await LibraryMetaStore.updateLastActiveCollection(
                        libraryURL,
                        collectionId: collectionID
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    func bind(searchIndex: SearchIndex) {
        print("✅ bind(searchIndex:) CALLED")

        self.boundSearchIndex = searchIndex

        // 🔑 CRITICAL: rebuild immediately with current state
        rebuildSearchIndex(searchIndex)

        $visibleNotes
            .sink { [weak self] _ in
                guard let self, let index = self.boundSearchIndex else { return }
                self.rebuildSearchIndex(index)
            }
            .store(in: &cancellables)
    }
    
    func resolveInitialLibrary() async {
        let config = await AppConfigStore.load()

        guard let url = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }

        // Validate the library still exists and is usable
        guard LibraryValidator.isLibraryRoot(url) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(url)
    }

    // MARK: - Library lifecycle

    func setActiveLibrary(_ url: URL) async {
        transitionToLoadedLibrary(url)

        var config = await AppConfigStore.load()
        config.lastLibraryURL = url
        await AppConfigStore.save(config)
    }

    func clearLibrary() async {
        transitionToNoLibrary()

        var config = await AppConfigStore.load()
        config.lastLibraryURL = nil
        await AppConfigStore.save(config)
    }

    // MARK: - Internal writes

    func beginInternalWrite(noteID: String? = nil) {
        internalWriteDepth &+= 1
        if let noteID {
            recordInternalWrite(noteID)
        }
    }

    func endInternalWrite(noteID: String? = nil) {
        internalWriteDepth = max(0, internalWriteDepth - 1)
        if let noteID {
            recordInternalWrite(noteID)
        }
    }

    private var isPerformingInternalWrite: Bool {
        internalWriteDepth > 0
    }

    func suppressEvents(for noteID: String) {
        recordInternalWrite(noteID)
    }

    private func recordInternalWrite(_ noteID: String) {
        recentInternalWrites[noteID] = Date()
    }

    private func cleanupInternalWrites() {
        guard !recentInternalWrites.isEmpty else { return }
        let threshold = Date().addingTimeInterval(-internalWriteCooldown)
        recentInternalWrites = recentInternalWrites.filter { _, timestamp in
            timestamp >= threshold
        }
    }

    private func shouldIgnore(noteID: String) -> Bool {
        cleanupInternalWrites()
        guard let timestamp = recentInternalWrites[noteID] else { return false }
        return Date().timeIntervalSince(timestamp) < internalWriteCooldown
    }

    // MARK: - Notes loading

    func loadNotes(
        libraryURL: URL,
        collection: String
    ) async {
        visibleCollectionID = collection

        do {
            let fetched = try await Task {
                try NoteStore.list(
                    libraryURL: libraryURL,
                    collection: collection
                )
            }.value

            guard visibleCollectionID == collection else { return }
            visibleNotes = sortNotes(fetched)
            boundSearchIndex.map { rebuildSearchIndex($0) }
        } catch {
            guard visibleCollectionID == collection else { return }
            visibleNotes = []
        }
    }

    func reloadCurrentCollection(
        preferredSelection: String? = nil,
        enforceSelection: Bool = false
    ) {
        guard
            let libraryURL = activeLibraryURL,
            let collection = visibleCollectionID
        else { return }

        Task {
            await loadNotes(
                libraryURL: libraryURL,
                collection: collection
            )

            if enforceSelection {
                finalizeSelectionAfterRemoval(preferred: preferredSelection)
            }
        }
    }

    // MARK: - Filesystem reconciliation

    func reconcile(_ events: [LibraryFilesystemEvent]) async {
        guard
            let libraryURL = activeLibraryURL,
            !isPerformingInternalWrite
        else { return }

        cleanupInternalWrites()

        var reconciliationEvents: [LibraryFilesystemEvent] = []
        reconciliationEvents.reserveCapacity(events.count)

        for event in events {
            switch event {
            case .added(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)
                handleAddition(
                    noteID: noteID,
                    libraryURL: libraryURL
                )

            case .modified(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)
                handleModification(
                    noteID: noteID,
                    libraryURL: libraryURL
                )

            case let .renamed(from, to):
                guard !shouldIgnore(noteID: from), !shouldIgnore(noteID: to) else { continue }
                reconciliationEvents.append(event)
                handleRename(
                    from: from,
                    to: to,
                    libraryURL: libraryURL
                )

            case .deleted(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)
                handleDeletion(noteID: noteID)

            case let .collectionRenamed(from, to):
                reconciliationEvents.append(event)
                handleCollectionRename(from: from, to: to, libraryURL: libraryURL)

            case let .collectionDeleted(collectionID):
                reconciliationEvents.append(event)
                handleCollectionDeletion(collectionID, libraryURL: libraryURL)

            case let .collectionAdded(collectionID):
                reconciliationEvents.append(event)
                handleCollectionAddition(collectionID, libraryURL: libraryURL)
            }
        }

        guard
            !reconciliationEvents.isEmpty,
            let index = libraryIndex
        else { return }

        let result = await LibraryIndexReconciler.applyEvents(
            reconciliationEvents,
            to: index,
            libraryURL: libraryURL
        )

        guard result.changed else { return }
        libraryIndex = result.index
        persistLibraryIndex(libraryURL: libraryURL)
    }
    
    @MainActor
    func replaceNoteID(oldID: String, newID: String) {
        
        updateLibraryIndexAfterRenameNote(
            oldID: oldID,
            newID: newID
        )
        
        if let libraryURL = activeLibraryURL {
            persistLibraryIndex(libraryURL: libraryURL)
        }
        
        // 1️⃣ Update selection immediately
        if selection?.selectedNoteID == oldID {
            selection?.selectedNoteID = newID
        }

        // 2️⃣ If the note is visible, rebuild its summary properly
        guard
            let libraryURL = activeLibraryURL,
            let index = visibleNotes.firstIndex(where: { $0.id == oldID })
        else {
            return
        }

        let oldSummary = visibleNotes[index]

        guard let newSummary = try? NoteSummaryFactory.make(
            libraryURL: libraryURL,
            noteID: newID,
            pinned: oldSummary.pinned
        ) else {
            return
        }

        visibleNotes.remove(at: index)
        visibleNotes.append(newSummary)
        visibleNotes = sortNotes(visibleNotes)

        signalExternalChange(for: newID)
    }

    @MainActor
    func refreshNoteID(_ noteID: String) {
        guard
            let libraryURL = activeLibraryURL,
            let index = visibleNotes.firstIndex(where: { $0.id == noteID })
        else {
            return
        }

        let pinned = visibleNotes[index].pinned

        guard let summary = try? NoteSummaryFactory.make(
            libraryURL: libraryURL,
            noteID: noteID,
            pinned: pinned
        ) else {
            return
        }

        visibleNotes.remove(at: index)
        visibleNotes.append(summary)
        visibleNotes = sortNotes(visibleNotes)

        signalExternalChange(for: noteID)
    }
    
    @discardableResult
    func prepareSelectionForRemoval(of noteID: String) -> (preferredNextID: String?, affectedVisibleList: Bool) {
        guard let index = visibleNotes.firstIndex(where: { $0.id == noteID }) else {
            return (nil, false)
        }

        let preferred = neighborID(around: index)

        if let preferred {
            selection?.selectNote(preferred)
        } else if visibleNotes.count == 1 {
            selection?.selectNote(nil)
        }

        return (preferred, true)
    }

    private func finalizeSelectionAfterRemoval(preferred: String?) {
        if visibleNotes.isEmpty {
            selection?.selectNote(nil)
            return
        }

        if let current = selection?.selectedNoteID,
           visibleNotes.contains(where: { $0.id == current }) {
            return
        }

        if let preferred,
           visibleNotes.contains(where: { $0.id == preferred }) {
            selection?.selectNote(preferred)
            return
        }

        selection?.selectNote(visibleNotes.first?.id)
    }

    private func neighborID(around index: Int) -> String? {
        if index + 1 < visibleNotes.count {
            return visibleNotes[index + 1].id
        }

        if index > 0 {
            return visibleNotes[index - 1].id
        }

        return nil
    }
    
    // MARK: - Note mutations

    func createNote(
        in collectionID: String,
        libraryURL: URL
    ) async -> String? {

        beginInternalWrite()
        defer { endInternalWrite() }

        let result: (summary: NoteSummary, content: String)

        do {
            result = try NoteStore.create(
                libraryURL: libraryURL,
                collection: collectionID,
                title: "Untitled"
            )
        } catch {
            print("Failed to create note:", error)
            return nil
        }

        // Reload for consistency (single source of truth)
        await loadNotes(
            libraryURL: libraryURL,
            collection: collectionID
        )
        
        updateLibraryIndexAfterCreateNote(
            noteID: result.summary.id,
            title: result.summary.title,
            collectionID: collectionID,
            libraryURL: libraryURL
        )
        persistLibraryIndex(libraryURL: libraryURL)

        return result.summary.id
    }
    
    func deleteNote(
        _ noteID: String,
        from collectionID: String,
        libraryURL: URL
    ) async {

        let selectionPlan = prepareSelectionForRemoval(of: noteID)

        beginInternalWrite(noteID: noteID)
        defer { endInternalWrite(noteID: noteID) }

        do {
            _ = try NoteStore.delete(
                libraryURL: libraryURL,
                noteID: noteID
            )
        } catch {
            print("Failed to delete note:", error)
        }

        await loadNotes(
            libraryURL: libraryURL,
            collection: collectionID
        )

        guard visibleCollectionID == collectionID else { return }
        
        updateLibraryIndexAfterDeleteNote(noteID: noteID, collectionID: collectionID)
        persistLibraryIndex(libraryURL: libraryURL)

        if selectionPlan.affectedVisibleList {
            finalizeSelectionAfterRemoval(preferred: selectionPlan.preferredNextID)
        }
    }
    
    // MARK: - Collections
    
    func createCollection(
        libraryURL: URL
    ) async -> String? {

        beginInternalWrite()
        defer { endInternalWrite() }

        let name = nextAvailableCollectionName(
            in: libraryURL
        )

        let collectionID: String

        do {
            collectionID = try CollectionStore.create(
                libraryURL: libraryURL,
                name: name
            )
        } catch {
            print("Failed to create collection:", error)
            return nil
        }

        updateLibraryIndexAfterCreateCollection(collectionID: collectionID)
        persistLibraryIndex(libraryURL: libraryURL)

        await reloadCollections(libraryURL: libraryURL)

        return collectionID
    }
    
    func renameCollection(
        from oldID: String,
        to newID: String,
        libraryURL: URL
    ) async {

        beginInternalWrite()
        defer { endInternalWrite() }

        let cleanID: String
        do {
            cleanID = try CollectionStore.rename(
                libraryURL: libraryURL,
                oldName: oldID,
                newName: newID
            )
        } catch {
            print("Failed to rename collection:", error)
            return
        }

        updateLibraryIndexAfterRenameCollection(from: oldID, to: cleanID)
        persistLibraryIndex(libraryURL: libraryURL)

        await reloadCollections(libraryURL: libraryURL)
    }
    
    // MARK: - Collections

    func deleteCollection(
        _ collectionID: String,
        libraryURL: URL
    ) async {

        guard !mandatoryCollections.contains(collectionID) else {
            print("Refusing to delete mandatory collection:", collectionID)
            return
        }

        guard visibleCollections.contains(collectionID) else { return }

        let nextSelection = neighborCollection(afterRemoving: collectionID)

        beginInternalWrite()
        defer { endInternalWrite() }

        do {
            try CollectionStore.delete(
                libraryURL: libraryURL,
                name: collectionID
            )
        } catch {
            print("Failed to delete collection:", error)
            return
        }

        updateLibraryIndexAfterDeleteCollection(collectionID: collectionID)
        persistLibraryIndex(libraryURL: libraryURL)

        await reloadCollections(libraryURL: libraryURL)

        if let next = nextSelection {
            selection?.selectCollection(next)
        } else {
            selection?.selectCollection(nil)
        }
    }
    
    // MARK: - Helpers
    
    private func transitionToLoadedLibrary(_ url: URL) {
        stopWatcher()
        activeLibraryURL = url
        startupState = .loaded(url)
        resetVisibleState()
        hasRunCatchUpReconciliation = false

        // ✅ NEW: load or create library index
        loadOrCreateLibraryIndex(libraryURL: url)

        Task {
            await ensureMandatoryCollectionsExist(libraryURL: url)
            await reloadCollections(libraryURL: url)
        }

        startWatcher(for: url)
        scheduleCatchUpReconciliation(libraryURL: url)
    }

    private func transitionToNoLibrary() {
        stopWatcher()
        activeLibraryURL = nil
        startupState = .noLibrary
        resetVisibleState()
        selection?.selectedNoteID = nil
    }

    private func resetVisibleState() {
        visibleNotes = []
        visibleCollectionID = nil
        currentNoteText = ""
        needsInitialCollectionSelection = true
        selection?.selectCollection(nil)
    }

    private func startWatcher(for url: URL) {
        let watcher = LibraryFilesystemWatcher(libraryURL: url) { [weak self] events in
            guard let self else { return }
            Task { @MainActor in
                guard !self.isPerformingInternalWrite else { return }
                await self.reconcile(events)
            }
        }
        watcher.start()
        filesystemWatcher = watcher
    }

    private func stopWatcher() {
        filesystemWatcher?.stop()
        filesystemWatcher = nil
    }

    private func isNoteInVisibleCollection(_ noteID: String) -> Bool {
        guard let visibleCollectionID else { return false }
        return noteID.hasPrefix("\(visibleCollectionID)/")
    }

    private func handleAddition(
        noteID: String,
        libraryURL: URL
    ) {
        guard isNoteInVisibleCollection(noteID) else { return }

        let pinned = visibleNotes.first(where: { $0.id == noteID })?.pinned ?? false
        guard let summary = try? NoteSummaryFactory.make(
            libraryURL: libraryURL,
            noteID: noteID,
            pinned: pinned
        ) else { return }

        upsert(summary)
    }
    
    private func nextAvailableCollectionName(
        in libraryURL: URL
    ) -> String {

        let base = "New Collection"
        let collectionsURL = libraryURL
            .appendingPathComponent(collectionsDir)

        let existing =
            (try? FileManager.default.contentsOfDirectory(
                at: collectionsURL,
                includingPropertiesForKeys: nil
            ))?
            .map { $0.lastPathComponent } ?? []

        if !existing.contains(base) {
            return base
        }

        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }

        return "\(base) \(index)"
    }
    
    private func neighborCollection(afterRemoving name: String) -> String? {
        guard let index = visibleCollections.firstIndex(of: name) else {
            return nil
        }

        if index + 1 < visibleCollections.count {
            return visibleCollections[index + 1]
        }

        if index > 0 {
            return visibleCollections[index - 1]
        }

        return nil
    }

    private func handleModification(
        noteID: String,
        libraryURL: URL
    ) {
        guard isNoteInVisibleCollection(noteID) else { return }
        let pinned = visibleNotes.first(where: { $0.id == noteID })?.pinned ?? false

        guard let summary = try? NoteSummaryFactory.make(
            libraryURL: libraryURL,
            noteID: noteID,
            pinned: pinned
        ) else { return }

        upsert(summary)
    }

    private func handleRename(
        from: String,
        to: String,
        libraryURL: URL
    ) {
        let wasVisible = isNoteInVisibleCollection(from)
        let isVisible = isNoteInVisibleCollection(to)
        let pinned = visibleNotes.first(where: { $0.id == from })?.pinned ?? false

        if wasVisible {
            removeNote(withID: from)
        }

        if isVisible {
            guard let summary = try? NoteSummaryFactory.make(
                libraryURL: libraryURL,
                noteID: to,
                pinned: pinned
            ) else { return }
            upsert(summary)
        }

        if selection?.selectedNoteID == from {
            selection?.selectedNoteID = to
            signalExternalChange(for: to)
        }
    }

    private func handleDeletion(noteID: String) {
        removeNote(withID: noteID)

        if selection?.selectedNoteID == noteID {
            selection?.selectedNoteID = nil
        }
    }

    private func handleCollectionRename(
        from: String,
        to: String,
        libraryURL: URL
    ) {
        guard from != to else { return }

        Task { [weak self] in
            guard let self else { return }
            await self.reloadCollections(libraryURL: libraryURL)
        }

        if visibleCollectionID == from {
            visibleCollectionID = to

            Task { [weak self] in
                guard let self else { return }
                await self.loadNotes(
                    libraryURL: libraryURL,
                    collection: to
                )
            }
        }

        if selection?.selectedCollectionID == from {
            selection?.selectedCollectionID = to
        }
    }

    private func handleCollectionDeletion(
        _ collectionID: String,
        libraryURL: URL
    ) {
        let nextSelection = neighborCollection(afterRemoving: collectionID)

        Task { [weak self] in
            guard let self else { return }
            await self.reloadCollections(libraryURL: libraryURL)
        }

        if visibleCollectionID == collectionID {
            visibleCollectionID = nil
            visibleNotes = []
            selection?.selectedNoteID = nil
        }

        if selection?.selectedCollectionID == collectionID {
            if let nextSelection {
                selection?.selectCollection(nextSelection)
            } else {
                selection?.selectCollection(nil)
            }
        }
    }

    private func handleCollectionAddition(
        _ collectionID: String,
        libraryURL: URL
    ) {
        guard !visibleCollections.contains(collectionID) else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.reloadCollections(libraryURL: libraryURL)
        }
    }

    private func upsert(_ summary: NoteSummary) {
        if let index = visibleNotes.firstIndex(where: { $0.id == summary.id }) {
            visibleNotes.remove(at: index)
        }

        visibleNotes.append(summary)
        visibleNotes = sortNotes(visibleNotes)
        signalExternalChange(for: summary.id)
    }

    private func removeNote(withID id: String) {
        guard let index = visibleNotes.firstIndex(where: { $0.id == id }) else {
            return
        }
        visibleNotes.remove(at: index)
        externalChangeTokens.removeValue(forKey: id)
    }

    private func sortNotes(_ notes: [NoteSummary]) -> [NoteSummary] {
        notes.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.id < rhs.id
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    private func signalExternalChange(for noteID: String) {
        externalChangeTokens[noteID] = UUID()
    }
    
    func reloadCollections(
        libraryURL: URL
    ) async {

        do {
            let collectionsURL = libraryURL
                .appendingPathComponent(collectionsDir)

            let items = try FileManager.default.contentsOfDirectory(
                at: collectionsURL,
                includingPropertiesForKeys: nil
            )

            let names = items
                .filter { $0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .sorted()

            visibleCollections = names
        } catch {
            visibleCollections = []
        }

        ensureCollectionSelection(libraryURL: libraryURL)
    }

    // Restores the last active collection (if available) and guarantees a valid fallback.
    private func ensureCollectionSelection(libraryURL: URL) {
        guard let selection else { return }

        let available = visibleCollections

        guard !available.isEmpty else {
            selection.selectCollection(nil)
            return
        }

        if let current = selection.selectedCollectionID,
           available.contains(current) {
            needsInitialCollectionSelection = false
            return
        }

        if needsInitialCollectionSelection,
           let restored = preferredInitialCollection(
               libraryURL: libraryURL,
               available: available
           ) {
            needsInitialCollectionSelection = false
            selection.selectCollection(restored)
            return
        }

        needsInitialCollectionSelection = false

        if let fallback = fallbackCollection(from: available) {
            selection.selectCollection(fallback)
        } else {
            selection.selectCollection(nil)
        }
    }

    private func preferredInitialCollection(
        libraryURL: URL,
        available: [String]
    ) -> String? {
        guard
            let meta = try? LibraryMetaStore.load(libraryURL),
            let preferred = meta.lastActiveCollectionId,
            available.contains(preferred)
        else {
            return nil
        }

        return preferred
    }

    private func fallbackCollection(from available: [String]) -> String? {
        if let inbox = available.first(where: { $0 == "Inbox" }) {
            return inbox
        }

        return available.first
    }
    
    func canRenameCollection(_ id: String) -> Bool {
        !mandatoryCollections.contains(id)
    }
    
    func collectionHasNotes(
        _ collectionID: String,
        libraryURL: URL
    ) -> Bool {
        do {
            let notes = try NoteStore.list(
                libraryURL: libraryURL,
                collection: collectionID
            )
            return !notes.isEmpty
        } catch {
            return false
        }
    }
    
    func ensureMandatoryCollectionsExist(libraryURL: URL) async {
        let collectionsURL = libraryURL.appendingPathComponent(collectionsDir)

        for name in mandatoryCollections {
            let url = collectionsURL.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            }
        }
    }
    
    func collectionID(for noteID: String) -> String {
        noteID.split(separator: "/").first.map(String.init) ?? "Inbox"
    }
    
    func rebuildSearchIndex(_ searchIndex: SearchIndex) {
        let entries: [SearchIndexEntry] = visibleNotes.compactMap { note in
            guard let markdown = markdownForNote(note) else { return nil }

            return SearchExtractor.extract(
                noteID: note.id,
                title: note.title,
                markdown: markdown
            )
        }
        
        print("🔍 SEARCH INDEXED:", entries.count, "notes")
        searchIndex.replaceAll(entries)
    }
    
    private func loadOrCreateLibraryIndex(libraryURL: URL) {
        let dir = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)

        let url = dir.appendingPathComponent("library.json")

        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let data = try? Data(contentsOf: url)
        let decodedIndex = data.flatMap {
            try? JSONDecoder().decode(LibraryIndex.self, from: $0)
        }

        if let index = decodedIndex,
           LibraryIndexBuilder.isSupportedVersion(index.version) {
            libraryIndex = index
            return
        }

        let existingLibraryID = decodedIndex?.libraryID
            ?? data.flatMap { LibraryIndexBuilder.extractLibraryID(from: $0) }

        libraryIndex = nil

        Task { [weak self] in
            guard let self else { return }
            await self.rebuildLibraryIndex(
                libraryURL: libraryURL,
                existingLibraryID: existingLibraryID
            )
        }
    }

    private func scheduleCatchUpReconciliation(libraryURL: URL) {
        guard !hasRunCatchUpReconciliation else { return }
        hasRunCatchUpReconciliation = true

        Task { [weak self] in
            guard let self else { return }
            await Task.yield()

            guard let index = self.libraryIndex else { return }

            let result = await LibraryIndexReconciler.reconcileAgainstFilesystem(
                libraryURL: libraryURL,
                index: index
            )

            guard result.changed else { return }
            self.libraryIndex = result.index
            self.persistLibraryIndex(libraryURL: libraryURL)
        }
    }

    func rebuildLibraryIndex(
        libraryURL: URL,
        existingLibraryID: String? = nil
    ) async {
        let libraryID = existingLibraryID ?? libraryIndex?.libraryID
        let rebuilt = await LibraryIndexBuilder.build(
            libraryURL: libraryURL,
            existingLibraryID: libraryID
        )
        libraryIndex = rebuilt
        persistLibraryIndex(libraryURL: libraryURL)
    }
    
    private func persistLibraryIndex(libraryURL: URL) {
        guard let libraryIndex else { return }

        let dir = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
        let url = dir.appendingPathComponent("library.json")
        let tmp = url.appendingPathExtension("tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(libraryIndex) else { return }

        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
        isLibraryIndexDirty = false
    }
    
    private func markLibraryIndexDirty() {
        isLibraryIndexDirty = true
    }

    private func updateLibraryIndexAfterCreateCollection(
        collectionID: String
    ) {
        guard var index = libraryIndex else { return }

        if index.collections[collectionID] == nil {
            index.collections[collectionID] = CollectionIndex(
                id: collectionID,
                noteIDs: []
            )
        }

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }

    private func updateLibraryIndexAfterRenameCollection(
        from oldID: String,
        to newID: String
    ) {
        guard var index = libraryIndex else { return }
        guard oldID != newID else { return }

        let oldCollection = index.collections.removeValue(forKey: oldID)
        let oldNoteIDs = oldCollection?.noteIDs ?? []

        var updatedNoteIDs: [String] = []
        updatedNoteIDs.reserveCapacity(oldNoteIDs.count)

        for noteID in oldNoteIDs {
            let newNoteID: String
            if noteID.hasPrefix("\(oldID)/") {
                let rest = noteID.dropFirst(oldID.count + 1)
                newNoteID = "\(newID)/\(rest)"
            } else {
                newNoteID = noteID
            }

            if let oldNote = index.notes.removeValue(forKey: noteID) {
                let updatedNote = NoteIndex(
                    id: newNoteID,
                    path: newNoteID,
                    title: oldNote.title,
                    modified: Date()
                )
                index.notes[newNoteID] = updatedNote
            }

            updatedNoteIDs.append(newNoteID)
        }

        index.collections[newID] = CollectionIndex(
            id: newID,
            noteIDs: updatedNoteIDs
        )

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }

    private func updateLibraryIndexAfterDeleteCollection(
        collectionID: String
    ) {
        guard var index = libraryIndex else { return }

        let noteIDs = index.collections[collectionID]?.noteIDs
            ?? index.notes.keys.filter { $0.hasPrefix("\(collectionID)/") }

        index.collections.removeValue(forKey: collectionID)

        for noteID in noteIDs {
            index.notes.removeValue(forKey: noteID)
        }

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterCreateNote(
        noteID: String,
        title: String,
        collectionID: String,
        libraryURL: URL
    ) {
        guard var index = libraryIndex else { return }

        // Ensure collection exists in index
        if index.collections[collectionID] == nil {
            index.collections[collectionID] = CollectionIndex(id: collectionID, noteIDs: [])
        }

        // Relative path: match your noteID convention (collection/note.md etc)
        // If your noteID is already "Collection/Filename.md", use it directly as path.
        let relativePath = noteID

        index.notes[noteID] = NoteIndex(
            id: noteID,
            path: relativePath,
            title: title,
            modified: Date()
        )

        if !(index.collections[collectionID]?.noteIDs.contains(noteID) ?? false) {
            index.collections[collectionID]?.noteIDs.append(noteID)
        }

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterDeleteNote(
        noteID: String,
        collectionID: String
    ) {
        guard var index = libraryIndex else { return }

        index.notes.removeValue(forKey: noteID)
        index.collections[collectionID]?.noteIDs.removeAll { $0 == noteID }

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterRenameNote(
        oldID: String,
        newID: String
    ) {
        guard var index = libraryIndex else { return }

        // Find existing note
        guard let oldNote = index.notes[oldID] else { return }

        // Determine collections
        let oldCollection = collectionID(for: oldID)
        let newCollection = collectionID(for: newID)

        // Remove old entry
        index.notes.removeValue(forKey: oldID)
        index.collections[oldCollection]?.noteIDs.removeAll { $0 == oldID }

        // Insert new entry
        let newNote = NoteIndex(
            id: newID,
            path: newID,          // matches your ID-as-path convention
            title: oldNote.title, // title already updated elsewhere
            modified: Date()
        )

        index.notes[newID] = newNote

        if index.collections[newCollection] == nil {
            index.collections[newCollection] = CollectionIndex(
                id: newCollection,
                noteIDs: []
            )
        }

        index.collections[newCollection]?.noteIDs.append(newID)

        index.lastUpdated = Date()
        libraryIndex = index
        markLibraryIndexDirty()
    }

}
