//
//  NoteStore+Rename.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

extension NoteStore {

    static func rename(
        libraryURL: URL,
        oldID: String,
        newTitle: String
    ) throws -> String {

        guard !oldID.isEmpty, !newTitle.isEmpty else {
            throw CoreError.invalidNoteID
        }

        let oldURL = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: oldID
        )

        // Ensure note exists
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw CoreError.noteNotFound
        }

        let collection = (oldID as NSString).deletingLastPathComponent
        let collectionDir = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(collection)

        let cleanTitle = newTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)

        let base = Slugify.make(cleanTitle)
        let newFilename = UniqueFilename.ensure(
            in: collectionDir,
            base: base
        )

        let newURL = collectionDir.appendingPathComponent(newFilename)

        try FileManager.default.moveItem(
            at: oldURL,
            to: newURL
        )

        let newID = "\(collection)/\(newFilename)"

        // ---- migrate metadata (pins) ----
        var meta = MetaStore.load(libraryURL: libraryURL)

        if meta.pinned[oldID] == true {
            meta.pinned.removeValue(forKey: oldID)
            meta.pinned[newID] = true
            try MetaStore.save(libraryURL: libraryURL, meta: meta)
        }

        return newID
    }
}
