//
//  TestLibrary.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// SoftdraftTests/Helpers/TestLibrary.swift

import Foundation

enum TestLibrary {

    static func makeTempLibrary() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        // Required Softdraft structure
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("collections/Inbox"),
            withIntermediateDirectories: true
        )

        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("assets"),
            withIntermediateDirectories: true
        )

        return base
    }
}
