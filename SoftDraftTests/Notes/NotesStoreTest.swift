//
//  NotesStoreTest.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// SoftdraftTests/Notes/NoteStoreTests.swift

import XCTest
@testable import SoftDraft

@MainActor
final class NoteStoreTests: XCTestCase {

    func testLoadAndSaveNote() throws {
        let library = try TestLibrary.makeTempLibrary()

        let noteID = "Inbox/test.md"
        let noteURL = library
            .appendingPathComponent("collections/Inbox/test.md")

        try "# Hello".write(
            to: noteURL,
            atomically: true,
            encoding: .utf8
        )

        let loaded = try NoteStore.load(
            libraryURL: library,
            noteID: noteID
        )

        XCTAssertEqual(loaded, "# Hello")

        let date = try NoteStore.save(
            libraryURL: library,
            noteID: noteID,
            content: "# Updated"
        )

        XCTAssertNotNil(date)
    }
}
