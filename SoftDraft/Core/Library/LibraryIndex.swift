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
}
