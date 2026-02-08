//
//  SearchExtractor.swift
//  SoftDraft
//
//  Created by Matt Adams on 08/02/2026.
//


import Foundation

enum SearchExtractor {

    static func extract(
        noteID: String,
        title: String,
        markdown: String
    ) -> SearchIndexEntry {

        var headings: [String] = []
        var bodyParts: [String] = []

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // ATX headings only (CommonMark subset you support)
            if line.hasPrefix("#") {
                let content = line
                    .drop { $0 == "#" }
                    .trimmingCharacters(in: .whitespaces)

                if !content.isEmpty {
                    headings.append(content)
                }
                continue
            }

            // Ignore fenced code blocks (cheap guard)
            if line.hasPrefix("```") {
                continue
            }

            bodyParts.append(line)
        }

        return SearchIndexEntry(
            id: noteID,
            title: SearchNormaliser.normalise(title),
            headings: headings.map { SearchNormaliser.normalise($0) },
            bodyText: SearchNormaliser.normalise(bodyParts.joined(separator: " "))
        )
    }
}