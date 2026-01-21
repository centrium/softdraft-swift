//
//  NoteCreateTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

final class NoteCreateTests: XCTestCase {

    func testCreateNoteDefaults() throws {
        let library = try TestLibrary.makeTempLibrary()

        let result = try NoteStore.create(
            libraryURL: library,
            collection: nil,
            title: nil
        )

        XCTAssertEqual(result.summary.relativeDir, "Inbox")
        XCTAssertEqual(result.summary.title, "Untitled")
        XCTAssertTrue(result.summary.id.hasPrefix("Inbox/"))
        XCTAssertTrue(result.content.hasPrefix("# Untitled"))
    }

    func testCreateNoteInCustomCollection() throws {
        let library = try TestLibrary.makeTempLibrary()

        let result = try NoteStore.create(
            libraryURL: library,
            collection: "Work",
            title: "My First Note"
        )

        XCTAssertEqual(result.summary.relativeDir, "Work")
        XCTAssertEqual(result.summary.title, "My First Note")
        XCTAssertEqual(result.summary.name, "my-first-note")
    }

    func testCreateEnsuresUniqueFilename() throws {
        let library = try TestLibrary.makeTempLibrary()

        _ = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Duplicate"
        )

        let second = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Duplicate"
        )

        XCTAssertTrue(second.summary.name.contains("duplicate-1"))
    }
}
