//
//  LibraryManager+Collections.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    // MARK: - Collections
    func allCollections() -> [String] {
        guard let libraryURL = currentLibraryURL else {
            return []
        }

        return (try? CollectionStore.list(libraryURL: libraryURL)) ?? []
    }
    
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

    @MainActor
    func selectCollection(_ collectionID: String?) {
        visibleTag = nil
        visibleCollectionID = collectionID
        updateVisibleNotes(selectedCollectionID: collectionID)
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
    func ensureCollectionSelection(libraryURL: URL) {
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

    func fallbackCollection(from available: [String]) -> String? {
        if let inbox = available.first(where: { $0 == "Inbox" }) {
            return inbox
        }

        return available.first
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
}
