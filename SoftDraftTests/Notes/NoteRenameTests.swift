//
//  NoteRenameTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

@MainActor
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

    func testRenameMigratesPin() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned Note"
        )

        var meta = try LibraryMetaStore.load(library)
        meta.pinned[created.summary.id] = true
        await LibraryMetaStore.save(meta, to: library)

        let newID = try NoteStore.rename(
            libraryURL: library,
            oldID: created.summary.id,
            newTitle: "Pinned Renamed"
        )

        let updatedMeta = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == nil &&
            meta.pinned[newID] == true
        }

        XCTAssertNil(updatedMeta.pinned[created.summary.id])
        XCTAssertEqual(updatedMeta.pinned[newID], true)
    }
}
