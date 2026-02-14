//
//  LibraryManager+Index.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    func loadOrCreateLibraryIndex(libraryURL: URL) {
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

    private func schedulePinnedMigration(libraryURL: URL) {
        Task { [weak self] in
            guard let self else { return }
            await self.migratePinnedStateIfNeeded(libraryURL: libraryURL)
        }
    }

    func migratePinnedStateIfNeeded(libraryURL: URL) async {
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

    func persistLibraryIndex(libraryURL: URL) {
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

    func updateLibraryIndexAfterCreateCollection(
        collectionID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.createCollection(
            index: index,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }

    func updateLibraryIndexAfterRenameCollection(
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

    func updateLibraryIndexAfterDeleteCollection(
        collectionID: String
    ) {
        guard let index = libraryIndex else { return }
        libraryIndex = LibraryIndexMutator.deleteCollection(
            index: index,
            collectionID: collectionID
        )
        markLibraryIndexDirty()
    }

    func updateLibraryIndexAfterCreateNote(
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

    func updateLibraryIndexAfterDeleteNote(
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

    func updateLibraryIndexAfterRenameNote(
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
