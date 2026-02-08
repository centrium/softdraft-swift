//
//  SearchIndex.swift
//  SoftDraft
//
//  Created by Matt Adams on 08/02/2026.
//


import Foundation
import Combine

@MainActor
final class SearchIndex: ObservableObject {

    @Published private(set) var entries: [SearchIndexEntry] = []
    private var entryByID: [String: SearchIndexEntry] = [:]

    func replaceAll(_ newEntries: [SearchIndexEntry]) {
        entries = newEntries
        entryByID = Dictionary(uniqueKeysWithValues: newEntries.map { ($0.id, $0) })
    }

    func upsert(_ entry: SearchIndexEntry) {
        entryByID[entry.id] = entry
        // Keep a stable array for predictable UI ordering.
        // Replace if exists else append.
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    func remove(noteID: String) {
        entryByID.removeValue(forKey: noteID)
        entries.removeAll { $0.id == noteID }
    }

    func search(_ rawQuery: String, limit: Int = 50) -> [SearchResult] {
        let query = SearchNormaliser.normalise(rawQuery)
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        results.reserveCapacity(32)

        for entry in entries {
            var score = 0
            var hint: String? = nil

            if entry.title.contains(query) {
                score += 100
                hint = hint ?? "Title"
            }

            if score < 100, let h = entry.headings.first(where: { $0.contains(query) }) {
                score += 50
                hint = hint ?? h
            }

            if score == 0, entry.bodyText.contains(query) {
                score += 10
                hint = hint ?? "Body"
            }

            if score > 0 {
                results.append(SearchResult(id: entry.id, score: score, matchHint: hint))
            }
        }

        results.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.id < b.id
        }

        if results.count > limit {
            results.removeSubrange(limit..<results.count)
        }

        return results
    }
}
