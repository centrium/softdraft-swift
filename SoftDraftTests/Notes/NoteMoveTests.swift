//
//  NoteMoveTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

final class NoteMoveTests: XCTestCase {

    func testMoveNoteToAnotherCollection() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Move Me"
        )

        let newID = try NoteStore.move(
            libraryURL: library,
            noteID: created.summary.id,
            destCollection: "Work"
        )

        XCTAssertTrue(newID.hasPrefix("Work/"))

        let movedURL = library
            .appendingPathComponent("collections/Work")
            .appendingPathComponent((newID as NSString).lastPathComponent)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: movedURL.path)
        )
    }

    func testMoveIsNoOpWhenSameCollection() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Stay Put"
        )

        let result = try NoteStore.move(
            libraryURL: library,
            noteID: created.summary.id,
            destCollection: "Inbox"
        )

        XCTAssertEqual(result, created.summary.id)
    }

    func testMoveEnsuresUniqueFilename() throws {
        let library = try TestLibrary.makeTempLibrary()

        _ = try NoteStore.create(
            libraryURL: library,
            collection: "Work",
            title: "Duplicate"
        )

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Duplicate"
        )

        let newID = try NoteStore.move(
            libraryURL: library,
            noteID: created.summary.id,
            destCollection: "Work"
        )

        XCTAssertTrue(newID.contains("duplicate-1"))
    }

    func testMoveMigratesPin() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned Move"
        )

        var meta = MetaStore.load(libraryURL: library)
        meta.pinned[created.summary.id] = true
        try MetaStore.save(libraryURL: library, meta: meta)

        let newID = try NoteStore.move(
            libraryURL: library,
            noteID: created.summary.id,
            destCollection: "Archive"
        )

        let updated = MetaStore.load(libraryURL: library)

        XCTAssertNil(updated.pinned[created.summary.id])
        XCTAssertEqual(updated.pinned[newID], true)
    }
}
