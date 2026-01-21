//
//  Meta.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

struct LibraryMeta: Codable {
    var version: Int = 1
    var lastActiveCollectionId: String?
    var pinned: [String: Bool] = [:]
}
