//
//  NoteTogglePinTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

@MainActor
final class NoteTogglePinTests: XCTestCase {

    func testTogglePinAddsPin() async throws {
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

        let isPinnedAfterToggle = updated.pinned
        XCTAssertTrue(isPinnedAfterToggle)

        _ = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == true
        }
    }

    @MainActor
    func testTogglePinRemovesPin() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Unpin Me"
        )

        // First toggle → pin
        _ = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        // Wait for meta to reflect pin
        _ = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == true
        }

        // Second toggle → unpin
        let updated = try NoteStore.togglePin(
            libraryURL: library,
            noteID: created.summary.id
        )

        XCTAssertFalse(updated.pinned)

        // Wait for meta to reflect unpin
        _ = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == nil
        }
    }

    func testTogglePinUsesH1AsTitle() async throws {
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

        let updatedTitle = updated.title
        XCTAssertEqual(updatedTitle, "Custom Title")

        _ = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == true
        }
    }
}
