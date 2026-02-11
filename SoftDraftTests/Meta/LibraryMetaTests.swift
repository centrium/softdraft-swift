import Foundation
import XCTest
@testable import SoftDraft

@MainActor
final class LibraryMetaStoreTests: XCTestCase {

    func testLoadReturnsDefaultWhenMissingFile() throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = try LibraryMetaStore.load(library)

        XCTAssertEqual(meta.version, 1)
        XCTAssertNil(meta.lastActiveCollectionId)
    }

    func testSavePersistsMetaToDisk() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = LibraryMeta(
            version: 3,
            lastActiveCollectionId: "Work"
        )

        await LibraryMetaStore.save(meta, to: library)

        let loaded = try LibraryMetaStore.load(library)

        XCTAssertEqual(loaded.version, 3)
        XCTAssertEqual(loaded.lastActiveCollectionId, "Work")
    }

    func testUpdateLastActiveCollection() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = LibraryMeta(
            version: 2,
            lastActiveCollectionId: "Inbox"
        )

        await LibraryMetaStore.save(meta, to: library)

        await LibraryMetaStore.updateLastActiveCollection(
            library,
            collectionId: "Archive"
        )

        let loaded = try LibraryMetaStore.load(library)

        XCTAssertEqual(loaded.lastActiveCollectionId, "Archive")
    }

    func testLoadLegacyPinnedReadsPinnedValues() throws {
        let library = try TestLibrary.makeTempLibrary()
        let url = library.appendingPathComponent(".softdraft-meta.json")

        let payload: [String: Any] = [
            "version": 1,
            "lastActiveCollectionId": "Inbox",
            "pinned": [
                "Inbox/alpha.md": true,
                "Work/beta.md": true
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: url, options: [.atomic])

        let pinned = LibraryMetaStore.loadLegacyPinned(library)

        XCTAssertEqual(
            pinned,
            ["Inbox/alpha.md": true, "Work/beta.md": true]
        )
    }
}
