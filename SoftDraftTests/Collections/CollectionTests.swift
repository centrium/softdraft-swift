//
//  CollectionTests.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import XCTest
@testable import SoftDraft

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

    func testRenameMigratesPins() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Pinned"
        )

        var meta = MetaStore.load(libraryURL: library)
        meta.pinned[created.summary.id] = true
        try MetaStore.save(libraryURL: library, meta: meta)

        _ = try CollectionStore.rename(
            libraryURL: library,
            oldName: "Inbox",
            newName: "Archive"
        )

        let updated = MetaStore.load(libraryURL: library)

        XCTAssertNil(updated.pinned[created.summary.id])
        XCTAssertEqual(
            updated.pinned["Archive/\(created.summary.name).md"],
            true
        )
    }

    func testDeleteCollectionRemovesPins() throws {
        let library = try TestLibrary.makeTempLibrary()

        let created = try NoteStore.create(
            libraryURL: library,
            collection: "Inbox",
            title: "Delete Collection"
        )

        var meta = MetaStore.load(libraryURL: library)
        meta.pinned[created.summary.id] = true
        try MetaStore.save(libraryURL: library, meta: meta)

        try CollectionStore.delete(
            libraryURL: library,
            name: "Inbox"
        )

        let updated = MetaStore.load(libraryURL: library)

        XCTAssertTrue(updated.pinned.isEmpty)
    }
}
