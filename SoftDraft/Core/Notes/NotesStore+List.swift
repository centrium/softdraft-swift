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
            do {
                let summary = try NoteSummaryFactory.make(
                    fileURL: url,
                    collection: collection
                )
                result.append(summary)
            } catch {
                continue
            }
        }

        return result.sorted {
            $0.modifiedAt > $1.modifiedAt
        }
    }
}
