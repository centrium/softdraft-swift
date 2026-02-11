//
//  LibraryIndex.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import Foundation

struct LibraryIndex: Codable {
    let version: Int
    let libraryID: String
    var lastUpdated: Date
    var collections: [String: CollectionIndex]
    var notes: [String: NoteIndex]
    var tagFrequencies: [String: Int] = [:]
}

struct CollectionIndex: Codable {
    let id: String
    var noteIDs: [String]
}

struct NoteIndex: Codable {
    let id: String
    let path: String      // relative path
    let title: String
    let modified: Date
    let pinned: Bool
    var tags: [String] = []

    init(
        id: String,
        path: String,
        title: String,
        modified: Date,
        pinned: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.path = path
        self.title = title
        self.modified = modified
        self.pinned = pinned
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case title
        case modified
        case pinned
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        title = try container.decode(String.self, forKey: .title)
        modified = try container.decode(Date.self, forKey: .modified)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(title, forKey: .title)
        try container.encode(modified, forKey: .modified)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(tags, forKey: .tags)
    }
}

extension LibraryIndex {
    mutating func applyTagDelta(oldTags: Set<String>, newTags: Set<String>) {
        for tag in oldTags.subtracting(newTags) {
            if let count = tagFrequencies[tag] {
                let next = count - 1
                if next <= 0 {
                    tagFrequencies.removeValue(forKey: tag)
                } else {
                    tagFrequencies[tag] = next
                }
            }
        }

        for tag in newTags.subtracting(oldTags) {
            tagFrequencies[tag, default: 0] += 1
        }
    }
}
