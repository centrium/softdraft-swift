//
//  CollectionStore+Create.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Collections/CollectionCreate.swift

import Foundation

extension CollectionStore {

    static func create(
        libraryURL: URL,
        name: String
    ) throws -> String {

        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw CoreError.collectionNotFound
        }

        let url = libraryURL
            .appendingPathComponent(collectionsDir)
            .appendingPathComponent(clean)

        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false
        )

        return clean
    }
}
