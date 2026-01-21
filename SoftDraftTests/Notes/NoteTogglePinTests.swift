//
//  NoteTogglePinTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

final class NoteTogglePinTests: XCTestCase {

    func testTogglePinAddsPin() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pin Me"
        )

        let updated = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        XCTAssertTrue(updated.pinned)
    }

    func testTogglePinRemovesPin() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Unpin Me"
        )

        _ = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        let updated = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        XCTAssertFalse(updated.pinned)
    }

    func testTogglePinUsesH1AsTitle() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Initial"
        )

        let url = library
            .appendingPathComponent("collections/Inbox")
            .appendingPathComponent("initial.md")

        try "# Custom Title\n\nBody".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )

        let updated = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        XCTAssertEqual(updated.title, "Custom Title")
    }
}
