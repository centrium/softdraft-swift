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
