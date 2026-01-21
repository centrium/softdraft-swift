//
//  NoteStore+Delete.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

extension NoteStore {

    static func delete(
        libraryURL: URL,
        noteID: String
    ) throws -> String {

        guard !noteID.isEmpty else {
            throw CoreError.invalidNoteID
        }

        let url = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: noteID
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CoreError.noteNotFound
        }

        try FileManager.default.removeItem(at: url)

        // ---- clean up metadata (pins etc) ----
        var meta = MetaStore.load(libraryURL: libraryURL)

        if meta.pinned[noteID] == true {
            meta.pinned.removeValue(forKey: noteID)
            try MetaStore.save(libraryURL: libraryURL, meta: meta)
        }

        return noteID
    }
}
