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

        // 1️⃣ Authoritative operation
        try FileManager.default.removeItem(at: url)

        // 2️⃣ Best-effort meta cleanup (async, non-blocking)
        Task {
            var meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()

            if meta.pinned.removeValue(forKey: noteID) != nil {
                await LibraryMetaStore.save(meta, to: libraryURL)
            }
        }

        return noteID
    }
}
