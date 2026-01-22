//
//  CollectionTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

@MainActor
final class CollectionStoreTests: XCTestCase {

    func testCreateAndListCollections() throws {
        let library = try TestLibrary.makeTempLibrary()

        _ = try CollectionStore.create(
            libraryURL: library,
            name: "Work"
        )

        let collections = try CollectionStore.list(libraryURL: library)

        XCTAssertTrue(collections.contains("Inbox"))
        XCTAssertTrue(collections.contains("Work"))
    }

    func testRenameMigratesPins() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned"
        )

        var meta = try LibraryMetaStore.load(library)
        meta.pinned[created.summary.id] = true
        await LibraryMetaStore.save(meta, to: library)

        _ = try CollectionStore.rename(
            libraryURL: library,
            oldName: "Inbox",
            newName: "Archive"
        )

        let updated = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned[created.summary.id] == nil &&
            meta.pinned["Archive/\(created.summary.name).md"] == true
        }

        XCTAssertNil(updated.pinned[created.summary.id])
        XCTAssertEqual(
            updated.pinned["Archive/\(created.summary.name).md"],
            true
        )
    }

    func testDeleteCollectionRemovesPins() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Delete Collection"
        )

        var meta = try LibraryMetaStore.load(library)
        meta.pinned[created.summary.id] = true
        await LibraryMetaStore.save(meta, to: library)

        try CollectionStore.delete(
            libraryURL: library,
            name: "Inbox"
        )

        let updated = try await waitForMetaUpdate(in: library) { meta in
            meta.pinned.isEmpty
        }

        XCTAssertTrue(updated.pinned.isEmpty)
    }
}
