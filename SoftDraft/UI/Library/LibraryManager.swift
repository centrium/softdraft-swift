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
    @Published private(set) var visibleTag: String? = nil
    
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
    private var hasRunPinnedMigration = false
    private var deferSearchIndexRebuild = false
    private var hasPendingSearchIndexRebuild = false
    private var searchIndexRebuildTask: Task<Void, Never>?
    
    struct TagItem: Identifiable {
    let id: String
    let count: Int
    }

    
    var allTagsSorted: [TagItem] {
        guard let index = libraryIndex else { return [] }
        
        // MARK: - Startup
        
        return index.tagFrequencies
            .map { TagItem(id: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.id < $1.id
                }
                return $0.count > $1.count
            }
    }

    func resolveInitialLibrarySync() {
        let config = AppConfigStore.loadSync()

        guard let url = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }

        guard LibraryValidator.isLibraryRoot(url) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(url)
    }

    func bind(selection: SelectionModel) {
        boundSearchIndex.map { scheduleSearchIndexRebuild($0) }
        self.selection = selection

        selection.$selectedCollectionID
            .removeDuplicates()
            .sink { [weak self] collectionID in
                self?.selectCollection(collectionID)
            }
            .store(in: &cancellables)

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
        scheduleSearchIndexRebuild(searchIndex)

        $visibleNotes
            .sink { [weak self] _ in
                guard let self, let index = self.boundSearchIndex else { return }
                self.scheduleSearchIndexRebuild(index)
            }
            .store(in: &cancellables)
    }
    
    func resolveInitialLibrary() async {
        guard case .resolving = startupState else { return }
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
        guard activeLibraryURL == libraryURL else { return }
        selectCollection(collection)
    }

    func loadNotesFromIndex(
        collection: String
    ) {
        selectCollection(collection)
    }

    func reloadCurrentCollection(
        preferredSelection: String? = nil,
        enforceSelection: Bool = false
    ) {
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

        if enforceSelection {
            finalizeSelectionAfterRemoval(preferred: preferredSelection)
        }
    }

    // MARK: - Filesystem reconciliation

    func reconcileSavedNoteImmediately(
        noteID: String,
        libraryURL: URL
    ) async {
        guard activeLibraryURL == libraryURL else { return }
        guard let index = libraryIndex else { return }

        let result = await LibraryIndexReconciler.applyEvents(
            [.modified(noteID: noteID)],
            to: index,
            libraryURL: libraryURL
        )

        guard activeLibraryURL == libraryURL else { return }
        guard result.changed else { return }
        libraryIndex = result.index
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        signalExternalChange(for: noteID)
    }

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

            case .modified(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)

            case let .renamed(from, to):
                guard !shouldIgnore(noteID: from), !shouldIgnore(noteID: to) else { continue }
                reconciliationEvents.append(event)
                if selection?.selectedNoteID == from {
                    selection?.selectedNoteID = to
                    signalExternalChange(for: to)
                }

            case .deleted(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)
                if selection?.selectedNoteID == noteID {
                    selection?.selectedNoteID = nil
                }

            case let .collectionRenamed(from, to):
                reconciliationEvents.append(event)
                if selection?.selectedCollectionID == from {
                    selection?.selectCollection(to)
                }

            case let .collectionDeleted(collectionID):
                reconciliationEvents.append(event)
                if selection?.selectedCollectionID == collectionID {
                    selection?.selectCollection(nil)
                }

            case .collectionAdded:
                reconciliationEvents.append(event)
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

        guard activeLibraryURL == libraryURL else { return }
        guard result.changed else { return }
        libraryIndex = result.index
        persistLibraryIndex(libraryURL: libraryURL)
        refreshVisibleStateFromIndex(libraryURL: libraryURL)
        validateSelectionInVisibleNotes()
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

        if selection?.selectedNoteID == oldID {
            selection?.selectedNoteID = newID
        }

        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        signalExternalChange(for: newID)
    }

    @MainActor
    func refreshNoteID(_ noteID: String) {
        guard libraryIndex?.notes[noteID] != nil else { return }
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
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

        updateLibraryIndexAfterCreateNote(
            noteID: result.summary.id,
            title: result.summary.title,
            collectionID: collectionID
        )
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

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
        
        updateLibraryIndexAfterDeleteNote(noteID: noteID, collectionID: collectionID)
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

        if selectionPlan.affectedVisibleList {
            finalizeSelectionAfterRemoval(preferred: selectionPlan.preferredNextID)
        }
    }

    func togglePin(
        noteID: String
    ) {
        guard
            let libraryURL = activeLibraryURL,
            let index = libraryIndex
        else { return }

        libraryIndex = LibraryIndexMutator.togglePin(
            index: index,
            noteID: noteID
        )
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
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
    
    // MARK: - Tags

    @MainActor
    func selectCollection(_ collectionID: String?) {
        visibleTag = nil
        visibleCollectionID = collectionID
        updateVisibleNotes(selectedCollectionID: collectionID)
        validateSelectionInVisibleNotes()
    }
    
    @MainActor
    func selectTag(_ tag: String) {
        visibleTag = tag
        visibleCollectionID = nil
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
    }
    
    @MainActor
    func clearTagSelection() {
        visibleTag = nil
        visibleCollectionID = selection?.selectedCollectionID
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
    }

    @MainActor
    func enterCollectionMode() {
        let targetCollection = selection?.selectedCollectionID ?? "Inbox"
        if selection?.selectedCollectionID != targetCollection {
            selection?.selectCollection(targetCollection)
            return
        }
        selectCollection(targetCollection)
    }

    @MainActor
    func enterTagMode() {
        visibleTag = nil
        visibleCollectionID = nil
        selection?.selectNote(nil)
        updateVisibleNotes()
    }
    
    // MARK: - Helpers

    private func validateSelectionInVisibleNotes() {
        guard let selectedNoteID = selection?.selectedNoteID else { return }
        guard visibleNotes.contains(where: { $0.id == selectedNoteID }) else {
            selection?.selectNote(nil)
            return
        }
    }

    private func updateVisibleNotes(selectedCollectionID: String? = nil) {
        guard let index = libraryIndex else {
            visibleNotes = []
            print("🔎 Mode:", visibleTag ?? selectedCollectionID ?? selection?.selectedCollectionID ?? "none")
            print("📄 Visible notes:", visibleNotes.count)
            return
        }

        if let visibleTag {
            visibleCollectionID = nil

            let summaries = index.notes.values
                .filter { $0.tags.contains(visibleTag) }
                .map { note in
                    summaryFromIndex(
                        noteID: note.id,
                        note: note,
                        fallbackCollection: collectionID(for: note.id)
                    )
                }

            visibleNotes = sortNotes(summaries)
        } else if let effectiveCollectionID = selectedCollectionID ?? selection?.selectedCollectionID {
            visibleCollectionID = effectiveCollectionID

            var candidateNoteIDs = Set(index.collections[effectiveCollectionID]?.noteIDs ?? [])
            let prefixedNoteIDs = index.notes.keys.filter {
                collectionID(for: $0) == effectiveCollectionID
            }
            candidateNoteIDs.formUnion(prefixedNoteIDs)

            let summaries = candidateNoteIDs.compactMap { noteID -> NoteSummary? in
                guard let note = index.notes[noteID] else { return nil }
                return summaryFromIndex(
                    noteID: noteID,
                    note: note,
                    fallbackCollection: effectiveCollectionID
                )
            }

            visibleNotes = sortNotes(summaries)
        } else {
            visibleCollectionID = selectedCollectionID
            visibleNotes = []
        }

        print("🔎 Mode:", visibleTag ?? selectedCollectionID ?? selection?.selectedCollectionID ?? "none")
        print("📄 Visible notes:", visibleNotes.count)
    }
    
    private func transitionToLoadedLibrary(_ url: URL) {
        stopWatcher()
        activeLibraryURL = url
        deferSearchIndexRebuild = true
        hasPendingSearchIndexRebuild = false
        searchIndexRebuildTask?.cancel()
        searchIndexRebuildTask = nil
        resetVisibleState()
        hasRunCatchUpReconciliation = false
        hasRunPinnedMigration = false

        // ✅ NEW: load or create library index
        loadOrCreateLibraryIndex(libraryURL: url)

        applyIndexSnapshot(libraryURL: url)

        startupState = .loaded(url)

        startPostLaunchTasks(for: url)
    }

    private func transitionToNoLibrary() {
        stopWatcher()
        activeLibraryURL = nil
        startupState = .noLibrary
        resetVisibleState()
        selection?.selectedNoteID = nil
        deferSearchIndexRebuild = false
        hasPendingSearchIndexRebuild = false
        searchIndexRebuildTask?.cancel()
        searchIndexRebuildTask = nil
    }

    private func resetVisibleState() {
        visibleTag = nil
        visibleCollectionID = nil
        currentNoteText = ""
        needsInitialCollectionSelection = true
        selection?.selectCollection(nil)
        updateVisibleNotes()
    }

    private func applyIndexSnapshot(libraryURL: URL) {
        guard let index = libraryIndex else {
            visibleCollections = []
            visibleCollectionID = nil
            updateVisibleNotes()
            return
        }

        visibleCollections = index.collections.keys.sorted()
        restoreInitialCollectionSelection(
            libraryURL: libraryURL,
            available: visibleCollections
        )

        if let selected = selection?.selectedCollectionID {
            selectCollection(selected)
        } else {
            visibleCollectionID = nil
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        }
    }

    private func restoreInitialCollectionSelection(
        libraryURL: URL,
        available: [String]
    ) {
        guard let selection else { return }

        if let current = selection.selectedCollectionID,
           available.contains(current) {
            needsInitialCollectionSelection = false
            return
        }

        guard !available.isEmpty else {
            needsInitialCollectionSelection = false
            selection.selectCollection(nil)
            return
        }

        if let meta = try? LibraryMetaStore.load(libraryURL),
           let preferred = meta.lastActiveCollectionId,
           available.contains(preferred) {
            needsInitialCollectionSelection = false
            selection.selectCollection(preferred)
            return
        }

        needsInitialCollectionSelection = false

        if let fallback = fallbackCollection(from: available) {
            selection.selectCollection(fallback)
        } else {
            selection.selectCollection(nil)
        }
    }

    private func refreshVisibleStateFromIndex(libraryURL: URL) {
        guard let index = libraryIndex else { return }

        visibleCollections = index.collections.keys.sorted()
        ensureCollectionSelection(libraryURL: libraryURL)

        if let selected = selection?.selectedCollectionID {
            if visibleTag == nil {
                visibleCollectionID = selected
            }
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        } else {
            visibleCollectionID = nil
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        }
    }

    private func startPostLaunchTasks(for url: URL) {
        Task { [weak self] in
            await Task.yield()
            await self?.runPostLaunchTasks(for: url)
        }
    }

    @MainActor
    private func runPostLaunchTasks(for url: URL) async {
        guard activeLibraryURL == url else { return }

        startWatcher(for: url)
        scheduleCatchUpReconciliation(libraryURL: url)

        deferSearchIndexRebuild = false
        if hasPendingSearchIndexRebuild,
           let searchIndex = boundSearchIndex {
            hasPendingSearchIndexRebuild = false
            rebuildSearchIndex(searchIndex)
        }

        await ensureMandatoryCollectionsExist(libraryURL: url)
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

    private func summaryFromIndex(
        noteID: String,
        note: NoteIndex,
        fallbackCollection: String
    ) -> NoteSummary {
        let parts = noteID.split(separator: "/", maxSplits: 1)
        let collectionID = parts.first.map(String.init) ?? fallbackCollection
        let filename = parts.count > 1 ? String(parts[1]) : (noteID as NSString).lastPathComponent
        let name = filename.replacingOccurrences(
            of: ".md",
            with: "",
            options: .caseInsensitive
        )
        let title = note.title.isEmpty ? name : note.title

        return NoteSummary(
            id: note.id,
            name: name,
            title: title,
            relativeDir: collectionID,
            modifiedAt: note.modified,
            pinned: note.pinned
        )
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
    
    private func scheduleSearchIndexRebuild(
        _ searchIndex: SearchIndex
    ) {
        guard !deferSearchIndexRebuild else {
            hasPendingSearchIndexRebuild = true
            return
        }

        rebuildSearchIndex(searchIndex)
    }

    func rebuildSearchIndex(_ searchIndex: SearchIndex) {
        guard
            let libraryURL = activeLibraryURL,
            let libraryIndex = libraryIndex
        else { return }

        let collectionsDir = collectionsDir
        let allNotes = libraryIndex.notes

        searchIndexRebuildTask?.cancel()

        searchIndexRebuildTask = Task.detached(priority: .utility) {

            var entries: [SearchIndexEntry] = []
            entries.reserveCapacity(allNotes.count)

            for (noteID, noteIndex) in allNotes {

                guard !Task.isCancelled else { return }

                // noteID format: "Collection/File.md"
                let parts = noteID.split(separator: "/", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let collectionID = String(parts[0])
                let filename = String(parts[1])

                let noteURL = libraryURL
                    .appendingPathComponent(collectionsDir)
                    .appendingPathComponent(collectionID)
                    .appendingPathComponent(filename)

                guard let markdown = try? String(contentsOf: noteURL, encoding: .utf8) else {
                    continue
                }

                entries.append(
                    SearchExtractor.extract(
                        noteID: noteID,
                        title: noteIndex.title,
                        markdown: markdown,
                        tags: noteIndex.tags
                    )
                )
            }

            guard !Task.isCancelled else { return }
            let builtEntries = entries

            await MainActor.run {
                guard !Task.isCancelled else { return }
                print("🔍 SEARCH INDEXED (GLOBAL):", builtEntries.count, "notes")
                searchIndex.replaceAll(builtEntries)
            }
        }
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
            print("🗂️ LibraryIndex loaded:", index.collections.count, "collections,", index.notes.count, "notes")
            libraryIndex = index
            schedulePinnedMigration(libraryURL: libraryURL)
            return
        }

        let existingLibraryID = decodedIndex?.libraryID
            ?? data.flatMap { LibraryIndexBuilder.extractLibraryID(from: $0) }

        if data == nil {
            print("🗂️ LibraryIndex missing; using empty index (filesystem reconcile pending)")
        } else if let decodedIndex {
            print(
                "🗂️ LibraryIndex unsupported version:",
                decodedIndex.version,
                "using empty index (filesystem reconcile pending)"
            )
        } else {
            print("🗂️ LibraryIndex unreadable; using empty index (filesystem reconcile pending)")
        }

        libraryIndex = LibraryIndex(
            version: LibraryIndexBuilder.supportedVersion,
            libraryID: existingLibraryID ?? UUID().uuidString,
            lastUpdated: Date(),
            collections: [:],
            notes: [:]
        )
    }

    private func scheduleCatchUpReconciliation(libraryURL: URL) {
        guard !hasRunCatchUpReconciliation else { return }
        hasRunCatchUpReconciliation = true

        Task { [weak self] in
            guard let self else { return }
            await Task.yield()

            guard self.activeLibraryURL == libraryURL else { return }
            guard let index = self.libraryIndex else { return }
            let baselineLastUpdated = index.lastUpdated

            let result = await LibraryIndexReconciler.reconcileAgainstFilesystem(
                libraryURL: libraryURL,
                index: index
            )

            guard self.activeLibraryURL == libraryURL else { return }
            guard self.libraryIndex?.lastUpdated == baselineLastUpdated else { return }
            guard result.changed else { return }
            self.libraryIndex = result.index
            self.persistLibraryIndex(libraryURL: libraryURL)
            self.refreshVisibleStateFromIndex(libraryURL: libraryURL)
            await self.migratePinnedStateIfNeeded(libraryURL: libraryURL)
        }
    }

    private func schedulePinnedMigration(libraryURL: URL) {
        Task { [weak self] in
            guard let self else { return }
            await self.migratePinnedStateIfNeeded(libraryURL: libraryURL)
        }
    }

    private func migratePinnedStateIfNeeded(libraryURL: URL) async {
        guard activeLibraryURL == libraryURL else { return }
        guard !hasRunPinnedMigration else { return }
        guard let index = libraryIndex else { return }

        hasRunPinnedMigration = true

        let legacyPinned = LibraryMetaStore.loadLegacyPinned(libraryURL)
        guard !legacyPinned.isEmpty else { return }

        var next = index
        var changed = false

        for (noteID, isPinned) in legacyPinned where isPinned {
            guard let existing = next.notes[noteID] else { continue }
            guard !existing.pinned else { continue }

            next = LibraryIndexMutator.setPinned(
                index: next,
                noteID: noteID,
                pinned: true
            )
            changed = true
        }

        if changed {
            libraryIndex = next
            persistLibraryIndex(libraryURL: libraryURL)
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        }

        let meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()
        await LibraryMetaStore.save(meta, to: libraryURL)
    }

    func rebuildLibraryIndex(
        libraryURL: URL,
        existingLibraryID: String? = nil
    ) async {
        let libraryID = existingLibraryID ?? libraryIndex?.libraryID
        let existingIndex = libraryIndex
        let rebuilt = await LibraryIndexBuilder.build(
            libraryURL: libraryURL,
            existingLibraryID: libraryID,
            existingIndex: existingIndex
        )
        guard activeLibraryURL == libraryURL else { return }
        libraryIndex = rebuilt
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        await migratePinnedStateIfNeeded(libraryURL: libraryURL)
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
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.createCollection(
            index: index,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }

    private func updateLibraryIndexAfterRenameCollection(
        from oldID: String,
        to newID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.renameCollection(
            index: index,
            oldID: oldID,
            newID: newID
        )
        markLibraryIndexDirty()
    }

    private func updateLibraryIndexAfterDeleteCollection(
        collectionID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.deleteCollection(
            index: index,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterCreateNote(
        noteID: String,
        title: String,
        collectionID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.createNote(
            index: index,
            noteID: noteID,
            title: title,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterDeleteNote(
        noteID: String,
        collectionID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.deleteNote(
            index: index,
            noteID: noteID,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }
    
    private func updateLibraryIndexAfterRenameNote(
        oldID: String,
        newID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.renameNote(
            index: index,
            oldID: oldID,
            newID: newID
        )
        markLibraryIndexDirty()
    }

}
