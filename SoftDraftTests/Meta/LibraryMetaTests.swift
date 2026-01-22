import XCTest
@testable import SoftDraft

@MainActor
final class LibraryMetaStoreTests: XCTestCase {

    func testLoadReturnsDefaultWhenMissingFile() throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = try LibraryMetaStore.load(library)

        XCTAssertEqual(meta.version, 1)
        XCTAssertNil(meta.lastActiveCollectionId)
        XCTAssertTrue(meta.pinned.isEmpty)
    }

    func testSavePersistsMetaToDisk() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = LibraryMeta(
            version: 3,
            lastActiveCollectionId: "Work",
            pinned: ["Inbox/today.md": true]
        )

        await LibraryMetaStore.save(meta, to: library)

        let loaded = try LibraryMetaStore.load(library)

        XCTAssertEqual(loaded.version, 3)
        XCTAssertEqual(loaded.lastActiveCollectionId, "Work")
        XCTAssertEqual(loaded.pinned, ["Inbox/today.md": true])
    }

    func testUpdateLastActiveCollectionPreservesPins() async throws {
        let library = try TestLibrary.makeTempLibrary()

        let meta = LibraryMeta(
            version: 2,
            lastActiveCollectionId: "Inbox",
            pinned: ["Inbox/alpha.md": true, "Work/beta.md": true]
        )

        await LibraryMetaStore.save(meta, to: library)
 
        await LibraryMetaStore.updateLastActiveCollection(
            library,
            collectionId: "Archive"
        )

        let loaded = try LibraryMetaStore.load(library)

        XCTAssertEqual(loaded.lastActiveCollectionId, "Archive")
        XCTAssertEqual(loaded.pinned, meta.pinned)
    }
}

final class MetaNormalizerTests: XCTestCase {

    func testAfterCollectionRenameMigratesPinnedKeys() {
        var meta = LibraryMeta()
        meta.pinned = [
            "Inbox/note-1.md": true,
            "Work/keep.md": true
        ]

        let updated = MetaNormalizer.afterCollectionRename(
            meta: meta,
            oldName: "Inbox",
            newName: "Archive"
        )

        XCTAssertNil(updated.pinned["Inbox/note-1.md"])
        XCTAssertEqual(updated.pinned["Archive/note-1.md"], true)
        XCTAssertEqual(updated.pinned["Work/keep.md"], true)
    }

    func testAfterCollectionDeleteDropsPinnedKeys() {
        var meta = LibraryMeta()
        meta.pinned = [
            "Inbox/remove.md": true,
            "Archive/keep.md": true
        ]

        let updated = MetaNormalizer.afterCollectionDelete(
            meta: meta,
            collection: "Inbox"
        )

        XCTAssertNil(updated.pinned["Inbox/remove.md"])
        XCTAssertEqual(updated.pinned["Archive/keep.md"], true)
    }
}
