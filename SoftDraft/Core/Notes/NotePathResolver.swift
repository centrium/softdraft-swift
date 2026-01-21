//
//  NotePathResolver.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Notes/NotePathResolver.swift

import Foundation

enum NotePathResolver {

    static func resolve(
        libraryURL: URL,
        noteID: String
    ) throws -> URL {

        guard !noteID.isEmpty else {
            throw CoreError.invalidNoteID
        }

        let clean = noteID
            .replacingOccurrences(of: #"^/+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^collections/"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\./+"#, with: "", options: .regularExpression)

        return libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(clean)
    }
}
