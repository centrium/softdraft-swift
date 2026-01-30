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
    private var cancellables: Set<AnyCancellable> = []
    let mandatoryCollections: Set<String> = ["Inbox"]

    private weak var selection: SelectionModel?
    private var filesystemWatcher: LibraryFilesystemWatcher?
    private var internalWriteDepth = 0
    private var recentInternalWrites: [String: Date] = [:]
    private let internalWriteCooldown: TimeInterval = 1.0

    // MARK: - Startup

    func bind(selection: SelectionModel) {
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

    func reconcile(_ event: LibraryFilesystemEvent) {
        guard
            let libraryURL = activeLibraryURL,
            !isPerformingInternalWrite
        else { return }

        cleanupInternalWrites()

        switch event {
        case .added(let noteID):
            guard !shouldIgnore(noteID: noteID) else { return }
            handleAddition(
                noteID: noteID,
                libraryURL: libraryURL
            )

        case .modified(let noteID):
            guard !shouldIgnore(noteID: noteID) else { return }
            handleModification(
                noteID: noteID,
                libraryURL: libraryURL
            )

        case let .renamed(from, to):
            guard !shouldIgnore(noteID: from), !shouldIgnore(noteID: to) else { return }
            handleRename(
                from: from,
                to: to,
                libraryURL: libraryURL
            )

        case .deleted(let noteID):
            guard !shouldIgnore(noteID: noteID) else { return }
            handleDeletion(noteID: noteID)
        }
    }
    
    @MainActor
    func replaceNoteID(oldID: String, newID: String) {
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

        do {
            try _ = CollectionStore.rename(
                libraryURL: libraryURL,
                oldName: oldID,
                newName: newID
            )
        } catch {
            print("Failed to rename collection:", error)
        }

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

        Task {
            await ensureMandatoryCollectionsExist(libraryURL: url)
            await reloadCollections(libraryURL: url)
        }

        startWatcher(for: url)
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
    }

    private func startWatcher(for url: URL) {
        let watcher = LibraryFilesystemWatcher(libraryURL: url) { [weak self] events in
            guard let self else { return }
            Task { @MainActor in
                guard !self.isPerformingInternalWrite else { return }
                for event in events {
                    self.reconcile(event)
                }
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
}
