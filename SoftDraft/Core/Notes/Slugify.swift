//
//  Slugify.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum Slugify {

    static func make(_ input: String) -> String {
        let lower = input.lowercased()

        let cleaned = lower
            .replacingOccurrences(of: #"[^a-z0-9\s-]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return cleaned.isEmpty ? "untitled" : cleaned
    }
}
