//
//  SearchIndexEntry.swift
//  SoftDraft
//
//  Created by Matt Adams on 08/02/2026.
//


import Foundation

struct SearchIndexEntry: Identifiable, Equatable {
    let id: String               // noteID
    let title: String            // normalised
    let headings: [String]       // normalised
    let bodyText: String         // normalised
}

struct SearchResult: Identifiable, Equatable {
    let id: String               // noteID
    let score: Int
    let matchHint: String?       // optional (title/heading snippet later)
}