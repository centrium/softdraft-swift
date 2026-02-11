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

}
