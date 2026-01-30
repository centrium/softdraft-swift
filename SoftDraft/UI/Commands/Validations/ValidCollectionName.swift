//
//  ValidCollectionName.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//

import Foundation

func isValidCollectionName(_ name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

    return trimmed.count >= 2 &&
           trimmed.count <= 30
}
