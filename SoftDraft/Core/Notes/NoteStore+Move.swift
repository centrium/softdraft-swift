//
//  NoteStore+Move.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

extension NoteStore {

    static func move(
        libraryURL: URL,
        noteID: String,
        destCollection: String
    ) throws -> String {

        guard !noteID.isEmpty, !destCollection.isEmpty else {
            throw CoreError.invalidNoteID
        }

        let oldURL = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: noteID
        )

        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw CoreError.noteNotFound
        }

        let srcCollection = (noteID as NSString).deletingLastPathComponent

        // No-op if same collection
        if srcCollection == destCollection {
            return noteID
        }

        let filename = (noteID as NSString).lastPathComponent
        let baseName = filename.replacingOccurrences(
            of: ".md",
            with: "",
            options: .caseInsensitive
        )

        let destDir = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(destCollection)

        try FileManager.default.createDirectory(
            at: destDir,
            withIntermediateDirectories: true
        )

        let newFilename = UniqueFilename.ensure(
            in: destDir,
            base: baseName
        )

        let newURL = destDir.appendingPathComponent(newFilename)

        try FileManager.default.moveItem(
            at: oldURL,
            to: newURL
        )

        let newID = "\(destCollection)/\(newFilename)"

        // ---- migrate metadata (pins) ----
        var meta = MetaStore.load(libraryURL: libraryURL)

        if meta.pinned[noteID] == true {
            meta.pinned.removeValue(forKey: noteID)
            meta.pinned[newID] = true
            try MetaStore.save(libraryURL: libraryURL, meta: meta)
        }

        return newID
    }
}
