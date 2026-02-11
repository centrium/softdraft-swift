//
//  SearchNormaliser.swift
//  SoftDraft
//
//  Created by Matt Adams on 08/02/2026.
//


import Foundation

enum SearchNormaliser {

    nonisolated static func normalise(_ input: String) -> String {
        // Cheap normalisation: lowercase + collapse whitespace
        let lower = input.lowercased()
        return lower.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
