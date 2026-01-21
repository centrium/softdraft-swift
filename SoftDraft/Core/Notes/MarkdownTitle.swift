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
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }
}
