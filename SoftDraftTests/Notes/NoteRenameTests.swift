//
//  NoteRenameTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

final class NoteRenameTests: XCTestCase {

    func testRenameNoteChangesFilename() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Original Title"
        )

        let newID = try NoteStore.rename(
            libraryURL: library,
            oldID: created.summary.id,
            newTitle: "Renamed Note"
        )

        XCTAssertTrue(newID.contains("renamed-note"))
    }

    func testRenamePreservesCollection() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Work",
            title: "Task"
        )

        let newID = try NoteStore.rename(
            libraryURL: library,
            oldID: created.summary.id,
            newTitle: "Updated Task"
        )

        XCTAssertTrue(newID.hasPrefix("Work/"))
    }

    func testRenameMigratesPin() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned Note"
        )

        var meta = MetaStore.load(libraryURL: library)
        meta.pinned[created.summary.id] = true
        try MetaStore.save(libraryURL: library, meta: meta)

        let newID = try NoteStore.rename(
            libraryURL: library,
            oldID: created.summary.id,
            newTitle: "Pinned Renamed"
        )

        let updatedMeta = MetaStore.load(libraryURL: library)

        XCTAssertNil(updatedMeta.pinned[created.summary.id])
        XCTAssertEqual(updatedMeta.pinned[newID], true)
    }
}

