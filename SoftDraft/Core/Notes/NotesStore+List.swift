//
//  NotesStore+List.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation

extension NoteStore {

    static func list(
        libraryURL: URL,
        collection: String
    ) throws -> [NoteSummary] {

        let dir = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(collection)

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var result: [NoteSummary] = []

        for url in urls where url.pathExtension == "md" {
            let attrs = try url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = attrs.contentModificationDate ?? Date()

            let id = "\(collection)/\(url.lastPathComponent)"
            let name = url.deletingPathExtension().lastPathComponent

            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let title = MarkdownTitle.extractH1(from: content) ?? name

            result.append(
                NoteSummary(
                    id: id,
                    name: name,
                    title: title,
                    relativeDir: collection,
                    modifiedAt: modified,
                    pinned: false // pins applied later
                )
            )
        }

        return result.sorted {
            $0.modifiedAt > $1.modifiedAt
        }
    }
}
