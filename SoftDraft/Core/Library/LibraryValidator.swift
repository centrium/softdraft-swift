//
//  LibraryValidator.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Library/LibraryValidator.swift

import Foundation

enum LibraryValidator {

    static let requiredDirectories = [
        "collections",
        "assets"
    ]

    static func isLibraryRoot(_ url: URL) -> Bool {
        let fm = FileManager.default

        return requiredDirectories.allSatisfy {
            fm.fileExists(
                atPath: url.appendingPathComponent($0).path
            )
        }
    }

    static func ensureLibraryStructure(at url: URL) throws {
        let fm = FileManager.default

        for dir in requiredDirectories {
            let path = url.appendingPathComponent(dir)
            try fm.createDirectory(
                at: path,
                withIntermediateDirectories: true
            )
        }

        // Optional: ensure Inbox exists
        let inbox = url
            .appendingPathComponent("collections")
            .appendingPathComponent("Inbox")

        try fm.createDirectory(
            at: inbox,
            withIntermediateDirectories: true
        )
    }
}
