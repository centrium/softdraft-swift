//
//  NoteStore+TogglePin.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

extension NoteStore {

    static func togglePin(
        libraryURL: URL,
        noteID: String
    ) throws -> NoteSummary {

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

        // Load meta
        var meta = MetaStore.load(libraryURL: libraryURL)

        let isPinned = meta.pinned[noteID] == true

        if isPinned {
            meta.pinned.removeValue(forKey: noteID)
        } else {
            meta.pinned[noteID] = true
        }

        try MetaStore.save(libraryURL: libraryURL, meta: meta)

        // Rebuild summary
        let content = try String(contentsOf: url, encoding: .utf8)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs[.modificationDate] as? Date ?? Date()

        let title = MarkdownTitle.extractH1(from: content)
            ?? (noteID as NSString).lastPathComponent.replacingOccurrences(
                of: ".md",
                with: ""
            )

        let relativeDir = (noteID as NSString).deletingLastPathComponent
        let name = (noteID as NSString).lastPathComponent.replacingOccurrences(
            of: ".md",
            with: ""
        )

        return NoteSummary(
            id: noteID,
            name: name,
            title: title,
            relativeDir: relativeDir,
            modifiedAt: modified,
            pinned: !isPinned
        )
    }
}
