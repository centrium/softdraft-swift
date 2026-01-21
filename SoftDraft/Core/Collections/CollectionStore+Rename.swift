//
//  CollectionStore+Rename.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Collections/CollectionRename.swift

import Foundation

extension CollectionStore {

    static func rename(
        libraryURL: URL,
        oldName: String,
        newName: String
    ) throws -> String {

        let cleanNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNew.isEmpty else {
            throw CoreError.collectionNotFound
        }

        let base = libraryURL.appendingPathComponent(collectionsDir)
        let oldURL = base.appendingPathComponent(oldName)
        let newURL = base.appendingPathComponent(cleanNew)

        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw CoreError.collectionNotFound
        }

        // 1️⃣ Perform the authoritative operation
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        // 2️⃣ Update meta best-effort (non-blocking)
        Task {
            let meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()
            let next = MetaNormalizer.afterCollectionRename(
                meta: meta,
                oldName: oldName,
                newName: cleanNew
            )
            await LibraryMetaStore.save(next, to: libraryURL)
        }

        return cleanNew
    }
}
