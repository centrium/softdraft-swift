//
//  NoteDeleteTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

final class NoteDeleteTests: XCTestCase {

    func testDeleteRemovesFile() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Delete Me"
        )

        let deletedID = try NoteStore.delete(
            libraryURL: library,
            noteID: created.summary.id
        )

        XCTAssertEqual(deletedID, created.summary.id)

        let deletedURL = library
            .appendingPathComponent("collections/Inbox")
            .appendingPathComponent("delete-me.md")

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: deletedURL.path)
        )
    }

    func testDeleteRemovesPin() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned Delete"
        )

        var meta = MetaStore.load(libraryURL: library)
        meta.pinned[created.summary.id] = true
        try MetaStore.save(libraryURL: library, meta: meta)

        _ = try NoteStore.delete(
            libraryURL: library,
            noteID: created.summary.id
        )

        let updated = MetaStore.load(libraryURL: library)

        XCTAssertNil(updated.pinned[created.summary.id])
    }

    func testDeleteThrowsIfMissing() throws {
        let library = try TestLibrary.makeTempLibrary()

        XCTAssertThrowsError(
            try NoteStore.delete(
                libraryURL: library,
                noteID: "Inbox/missing.md"
            )
        )
    }
}
