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
}
