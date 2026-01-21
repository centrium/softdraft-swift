//
//  NoteStore+Create.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

extension NoteStore {

    static func create(
        libraryURL: URL,
        collection: String?,
        title: String?
    ) throws -> (summary: NoteSummary, content: String) {

        let safeCollection = (collection?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Inbox"

        let safeTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Untitled"

        let collectionDir = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(safeCollection)

        try FileManager.default.createDirectory(
            at: collectionDir,
            withIntermediateDirectories: true
        )

        let base = Slugify.make(safeTitle)
        let filename = UniqueFilename.ensure(
            in: collectionDir,
            base: base
        )

        let fileURL = collectionDir.appendingPathComponent(filename)

        let content = "# \(safeTitle)\n\n"

        try content.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )

        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modified = attrs[.modificationDate] as? Date ?? Date()

        let id = "\(safeCollection)/\(filename)"

        let summary = NoteSummary(
            id: id,
            name: filename.replacingOccurrences(of: ".md", with: ""),
            title: safeTitle,
            relativeDir: safeCollection,
            modifiedAt: modified,
            pinned: false
        )

        return (summary, content)
    }
}
