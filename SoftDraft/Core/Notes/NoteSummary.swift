//
//  NoteSummary.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

struct NoteSummary: Equatable {
    let id: String
    let name: String
    let title: String
    let relativeDir: String
    let modifiedAt: Date
    let pinned: Bool
}
