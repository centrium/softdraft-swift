//
//  MetaStore.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum LibraryMetaStore {

    private static let fileName = ".softdraft-meta.json"

    private static func metaURL(for libraryURL: URL) -> URL {
        libraryURL.appendingPathComponent(fileName)
    }

    static func load(_ libraryURL: URL) throws -> LibraryMeta {
        let url = metaURL(for: libraryURL)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return LibraryMeta()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LibraryMeta.self, from: data)
    }

    static func save(_ meta: LibraryMeta, to libraryURL: URL) async {
        let url = metaURL(for: libraryURL)

        do {
            let data = try JSONEncoder().encode(meta)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Failed to save library meta: \(error)")
        }
    }

    // Convenience: update only lastActiveCollection
    static func updateLastActiveCollection(
        _ libraryURL: URL,
        collectionId: String
    ) async {
        var meta = (try? load(libraryURL)) ?? LibraryMeta()
        meta.lastActiveCollectionId = collectionId
        await save(meta, to: libraryURL)
    }
}
