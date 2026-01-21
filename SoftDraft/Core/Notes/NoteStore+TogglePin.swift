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

        // 1️⃣ Determine new pin state (best-effort read)
        let meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()
        let isPinned = meta.pinned[noteID] == true
        let nextPinned = !isPinned

        // 2️⃣ Persist pin toggle asynchronously (non-blocking)
        Task {
            var nextMeta = meta

            if nextPinned {
                nextMeta.pinned[noteID] = true
            } else {
                nextMeta.pinned.removeValue(forKey: noteID)
            }

            await LibraryMetaStore.save(nextMeta, to: libraryURL)
        }

        // 3️⃣ Rebuild summary synchronously (authoritative for UI)
        let content = try String(contentsOf: url, encoding: .utf8)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs[.modificationDate] as? Date ?? Date()

        let title = MarkdownTitle.extractH1(from: content)
            ?? (noteID as NSString)
                .lastPathComponent
                .replacingOccurrences(of: ".md", with: "")

        let relativeDir = (noteID as NSString).deletingLastPathComponent
        let name = (noteID as NSString)
            .lastPathComponent
            .replacingOccurrences(of: ".md", with: "")

        return NoteSummary(
            id: noteID,
            name: name,
            title: title,
            relativeDir: relativeDir,
            modifiedAt: modified,
            pinned: nextPinned
        )
    }
}
