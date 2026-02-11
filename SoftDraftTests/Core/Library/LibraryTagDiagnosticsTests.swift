import XCTest
@testable import SoftDraft

@MainActor
final class LibraryTagDiagnosticsTests: XCTestCase {
    func testSavePathWithTargetedReconcileUpdatesAndPersistsTags() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let noteID = "Inbox/tag-diagnostic.md"
        let noteURL = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent("Inbox")
            .appendingPathComponent("tag-diagnostic.md")

        try "# Heading\n\nInitial body".write(to: noteURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: noteURL.path
        )

        let manager = LibraryManager()
        let selection = SelectionModel()
        manager.bind(selection: selection)
        await manager.setActiveLibrary(libraryURL)
        await manager.rebuildLibraryIndex(libraryURL: libraryURL)

        manager.beginInternalWrite(noteID: noteID)
        _ = try NoteStore.save(
            libraryURL: libraryURL,
            noteID: noteID,
            content: "# Heading\n\nNow has #work"
        )
        await manager.reconcileSavedNoteImmediately(
            noteID: noteID,
            libraryURL: libraryURL
        )
        manager.endInternalWrite(noteID: noteID)

        XCTAssertEqual(manager.libraryIndex?.notes[noteID]?.tags, ["work"])
        XCTAssertEqual(manager.libraryIndex?.tagFrequencies["work"], 1)

        let persistedURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        let persistedData = try Data(contentsOf: persistedURL)
        let persistedIndex = try JSONDecoder().decode(LibraryIndex.self, from: persistedData)
        XCTAssertEqual(persistedIndex.notes[noteID]?.tags, ["work"])
        XCTAssertEqual(persistedIndex.tagFrequencies["work"], 1)
    }

    func testRebuildLibraryIndexPreservesTagsParsedFromDisk() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let noteID = "Inbox/rebuild-tags.md"
        let noteURL = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent("Inbox")
            .appendingPathComponent("rebuild-tags.md")

        try "# Heading\n\nBody #work #Focus".write(
            to: noteURL,
            atomically: true,
            encoding: .utf8
        )

        let manager = LibraryManager()
        let selection = SelectionModel()
        manager.bind(selection: selection)
        await manager.setActiveLibrary(libraryURL)

        await manager.rebuildLibraryIndex(libraryURL: libraryURL)

        XCTAssertEqual(manager.libraryIndex?.notes[noteID]?.tags, ["focus", "work"])
        XCTAssertEqual(manager.libraryIndex?.tagFrequencies, ["focus": 1, "work": 1])

        let persistedURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        let persistedData = try Data(contentsOf: persistedURL)
        let persistedIndex = try JSONDecoder().decode(LibraryIndex.self, from: persistedData)
        XCTAssertEqual(persistedIndex.notes[noteID]?.tags, ["focus", "work"])
        XCTAssertEqual(persistedIndex.tagFrequencies, ["focus": 1, "work": 1])
    }

    func testRebuildLibraryIndexPreservesPinnedForSurvivingNotesOnly() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let collectionsURL = libraryURL.appendingPathComponent("collections")
        let keepNoteID = "Inbox/keep.md"
        let removeNoteID = "Inbox/remove.md"
        let newNoteID = "Inbox/new.md"

        let keepURL = collectionsURL
            .appendingPathComponent("Inbox")
            .appendingPathComponent("keep.md")
        let removeURL = collectionsURL
            .appendingPathComponent("Inbox")
            .appendingPathComponent("remove.md")
        let newURL = collectionsURL
            .appendingPathComponent("Inbox")
            .appendingPathComponent("new.md")

        try "Body #work".write(to: keepURL, atomically: true, encoding: .utf8)
        try "Body #old".write(to: removeURL, atomically: true, encoding: .utf8)

        let manager = LibraryManager()
        let selection = SelectionModel()
        manager.bind(selection: selection)
        await manager.setActiveLibrary(libraryURL)
        await manager.rebuildLibraryIndex(libraryURL: libraryURL)

        manager.togglePin(noteID: keepNoteID)
        manager.togglePin(noteID: removeNoteID)

        try FileManager.default.removeItem(at: removeURL)
        try "Body #work #new".write(to: newURL, atomically: true, encoding: .utf8)

        await manager.rebuildLibraryIndex(libraryURL: libraryURL)

        XCTAssertEqual(manager.libraryIndex?.notes[keepNoteID]?.pinned, true)
        XCTAssertEqual(manager.libraryIndex?.notes[newNoteID]?.pinned, false)
        XCTAssertNil(manager.libraryIndex?.notes[removeNoteID])

        XCTAssertEqual(manager.libraryIndex?.notes[keepNoteID]?.tags, ["work"])
        XCTAssertEqual(manager.libraryIndex?.notes[newNoteID]?.tags, ["new", "work"])
        XCTAssertEqual(manager.libraryIndex?.tagFrequencies, ["new": 1, "work": 2])
    }
}
