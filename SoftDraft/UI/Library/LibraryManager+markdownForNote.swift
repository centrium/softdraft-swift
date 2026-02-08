//
//  LibraryManager+.swift
//  SoftDraft
//
//  Created by Matt Adams on 08/02/2026.
//

import SwiftUI

extension LibraryManager {

    func markdownForNote(_ note: NoteSummary) -> String? {
        guard let libraryURL = activeLibraryURL else { return nil }

        let fileName = note.name.hasSuffix(".md")
            ? note.name
            : note.name + ".md"

        let noteURL = libraryURL
            .appendingPathComponent(collectionsDir)
            .appendingPathComponent(note.relativeDir)
            .appendingPathComponent(fileName)

        return try? String(contentsOf: noteURL)
    }
}
