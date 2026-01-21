//
//  NoteStore.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Notes/NoteStore.swift

import Foundation

struct NoteStore {

    static func load(
        libraryURL: URL,
        noteID: String
    ) throws -> String {

        let url = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: noteID
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CoreError.noteNotFound
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    static func save(
        libraryURL: URL,
        noteID: String,
        content: String
    ) throws -> Date {

        guard !content.isEmpty else {
            throw CoreError.invalidContent
        }

        let url = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: noteID
        )

        try content.write(to: url, atomically: true, encoding: .utf8)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.modificationDate] as? Date ?? Date()
    }
}
