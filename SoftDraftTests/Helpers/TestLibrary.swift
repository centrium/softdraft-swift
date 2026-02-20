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

        let indexDirectory = base.appendingPathComponent(".softdraft", isDirectory: true)
        try FileManager.default.createDirectory(
            at: indexDirectory,
            withIntermediateDirectories: true
        )

        let indexObject: [String: Any] = [
            "version": 1,
            "libraryID": UUID().uuidString,
            "lastUpdated": Date().timeIntervalSinceReferenceDate,
            "collections": [
                "Inbox": [
                    "id": "Inbox",
                    "noteIDs": [String]()
                ]
            ],
            "notes": [String: Any](),
            "tagFrequencies": [String: Int]()
        ]

        let indexData = try JSONSerialization.data(
            withJSONObject: indexObject,
            options: []
        )
        try indexData.write(
            to: indexDirectory.appendingPathComponent("library.json"),
            options: [.atomic]
        )

        return base
    }
}
