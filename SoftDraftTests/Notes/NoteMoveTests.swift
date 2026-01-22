//
//  NoteMoveTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

@MainActor
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

    func testMoveMigratesPin() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned Move"
        )

        var meta = try LibraryMetaStore.load(library)
        meta.pinned[created.summary.id] = true
        await LibraryMetaStore.save(meta, to: library)

        let newID = try NoteStore.move(
            libraryURL: library,
            noteID: created.summary.id,
            destCollection: "Archive"
        )

        let updated = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == nil &&
            meta.pinned[newID] == true
        }

        XCTAssertNil(updated.pinned[created.summary.id])
        XCTAssertEqual(updated.pinned[newID], true)
    }
}
