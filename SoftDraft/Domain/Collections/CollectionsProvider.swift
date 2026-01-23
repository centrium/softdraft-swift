//
//  CollectionsProvider.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
//

import Foundation

protocol CollectionsSnapshot {
    func allCollections() throws -> [String]
}
