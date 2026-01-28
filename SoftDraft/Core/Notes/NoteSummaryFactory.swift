//
//  NoteSummaryFactory.swift
//  SoftDraft
//
//  Created by ChatGPT on 05/02/2026.
//

import Foundation

enum NoteSummaryFactory {

    static func make(
        libraryURL: URL,
        noteID: String,
        pinned: Bool = false
    ) throws -> NoteSummary {
        let url = try NotePathResolver.resolve(
            libraryURL: libraryURL,
            noteID: noteID
        )

        let collection = (noteID as NSString).deletingLastPathComponent
        return try make(
            fileURL: url,
            collection: collection,
            pinned: pinned
        )
    }

    static func make(
        fileURL: URL,
        collection: String,
        pinned: Bool = false
    ) throws -> NoteSummary {

        let attrs = try FileManager.default.attributesOfItem(
            atPath: fileURL.path
        )
        let modified = attrs[.modificationDate] as? Date ?? Date()

        let name = fileURL
            .deletingPathExtension()
            .lastPathComponent

        let content = (try? String(
            contentsOf: fileURL,
            encoding: .utf8
        )) ?? ""

        let title = MarkdownTitle.extractH1(from: content) ?? name

        return NoteSummary(
            id: "\(collection)/\(fileURL.lastPathComponent)",
            name: name,
            title: title,
            relativeDir: collection,
            modifiedAt: modified,
            pinned: pinned
        )
    }
}

