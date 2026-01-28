//
//  MarkdownTitle.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum MarkdownTitle {

    static func extractH1(from content: String) -> String? {
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("# ") else { continue }

            let title = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : String(title)
        }
        return nil
    }
}

func RenameNote(
    libraryURL: URL,
    noteID: String,
    content: String
) throws -> String? {

    // 1. Extract desired title
    guard let title = MarkdownTitle.extractH1(from: content) else {
        return nil
    }

    // 2. Work out current vs desired filename
    let currentFilename = (noteID as NSString).lastPathComponent
    let currentSlug = currentFilename
        .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)

    let desiredSlug = Slugify.make(title)

    // 3. No-op if nothing changed
    guard !desiredSlug.isEmpty, desiredSlug != currentSlug else {
        return nil
    }

    // 4. Authoritative rename
    return try NoteStore.rename(
        libraryURL: libraryURL,
        oldID: noteID,
        newTitle: title
    )
}
