//
//  CollectionStore+Delete.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Collections/CollectionDelete.swift

import Foundation

extension CollectionStore {

    static func delete(
        libraryURL: URL,
        name: String
    ) throws {

        let url = libraryURL
            .appendingPathComponent(collectionsDir)
            .appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CoreError.collectionNotFound
        }

        try FileManager.default.removeItem(at: url)

        let meta = MetaStore.load(libraryURL: libraryURL)
        let next = MetaNormalizer.afterCollectionDelete(
            meta: meta,
            collection: name
        )

        try MetaStore.save(libraryURL: libraryURL, meta: next)
    }
}
