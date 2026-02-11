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

    init(
        id: String,
        path: String,
        title: String,
        modified: Date,
        pinned: Bool = false
    ) {
        self.id = id
        self.path = path
        self.title = title
        self.modified = modified
        self.pinned = pinned
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case title
        case modified
        case pinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        title = try container.decode(String.self, forKey: .title)
        modified = try container.decode(Date.self, forKey: .modified)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(title, forKey: .title)
        try container.encode(modified, forKey: .modified)
        try container.encode(pinned, forKey: .pinned)
    }
}
