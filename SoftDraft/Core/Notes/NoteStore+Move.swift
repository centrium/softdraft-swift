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

        // 1️⃣ Authoritative operation
        try FileManager.default.moveItem(
            at: oldURL,
            to: newURL
        )

        let newID = "\(destCollection)/\(newFilename)"

        // 2️⃣ Best-effort meta migration (async, non-blocking)
        Task {
            var meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()

            if meta.pinned.removeValue(forKey: noteID) != nil {
                meta.pinned[newID] = true
                await LibraryMetaStore.save(meta, to: libraryURL)
            }
        }

        return newID
    }
}
