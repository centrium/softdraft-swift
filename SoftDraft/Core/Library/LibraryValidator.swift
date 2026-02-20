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
    static let requiredLibraryConfigPath = ".softdraft/library.json"

    static func isLibraryRoot(_ url: URL) -> Bool {
        let rootURL = url.standardizedFileURL
        let fm = FileManager.default

        let hasRequiredDirectories = requiredDirectories.allSatisfy { directory in
            var isDirectory: ObjCBool = false
            let directoryURL = rootURL.appendingPathComponent(directory, isDirectory: true)
            guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
                return false
            }
            return isDirectory.boolValue
        }

        guard hasRequiredDirectories else { return false }

        let configURL = rootURL.appendingPathComponent(requiredLibraryConfigPath)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: configURL.path, isDirectory: &isDirectory) else {
            return false
        }

        return !isDirectory.boolValue
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
