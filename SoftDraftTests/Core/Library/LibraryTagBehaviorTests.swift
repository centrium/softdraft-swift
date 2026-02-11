import Foundation
import XCTest
@testable import SoftDraft

@MainActor
final class LibraryTagBehaviorTests: XCTestCase {

    func testTagParserExtractsLowercasedUniqueTags() {
        let markdown = """
        # Heading
        body #Work #work #foo-bar #bar_baz #9abc #abc9
        """

        let tags = TagParser.parseTags(from: markdown)

        XCTAssertEqual(tags, ["work", "foo-bar", "bar_baz", "9abc", "abc9"])
    }

    func testTagParserIgnoresFencedAndInlineCodeAndHeadings() {
        let markdown = """
        # Heading Title
        visible #real

        `inline #skip_inline`

        ```swift
        let v = "#skip_fenced_backticks"
        ```

        ~~~
        #skip_fenced_tildes
        ~~~
        """

        let tags = TagParser.parseTags(from: markdown)

        XCTAssertEqual(tags, ["real"])
    }

    func testUpdateNoteFromFilesystemParsesTagsOnAddAndSetsFrequencies() throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let noteID = "Inbox/tags.md"
        try writeMarkdown("body #Work #todo #work", to: noteID, in: libraryURL)

        let updated = LibraryIndexMutator.updateNoteFromFilesystem(
            index: makeIndex(),
            noteID: noteID,
            filesystemData: .init(title: "tags", modified: Date(timeIntervalSince1970: 100)),
            libraryURL: libraryURL
        )

        XCTAssertEqual(updated.notes[noteID]?.tags, ["todo", "work"])
        XCTAssertEqual(updated.tagFrequencies, ["todo": 1, "work": 1])
    }

    func testUpdateNoteFromFilesystemModifyAppliesDeltaWithoutFrequencyDrift() throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let noteID = "Inbox/tags.md"
        try writeMarkdown("body #work #new", to: noteID, in: libraryURL)

        let initial = makeIndex(
            notes: [
                noteID: NoteIndex(
                    id: noteID,
                    path: noteID,
                    title: "tags",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["old", "work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            tagFrequencies: ["old": 1, "work": 1]
        )

        let once = LibraryIndexMutator.updateNoteFromFilesystem(
            index: initial,
            noteID: noteID,
            filesystemData: .init(modified: Date(timeIntervalSince1970: 200)),
            libraryURL: libraryURL
        )

        XCTAssertEqual(once.notes[noteID]?.tags, ["new", "work"])
        XCTAssertEqual(once.tagFrequencies, ["new": 1, "work": 1])

        let twice = LibraryIndexMutator.updateNoteFromFilesystem(
            index: once,
            noteID: noteID,
            filesystemData: .init(modified: Date(timeIntervalSince1970: 300)),
            libraryURL: libraryURL
        )

        XCTAssertEqual(twice.notes[noteID]?.tags, ["new", "work"])
        XCTAssertEqual(twice.tagFrequencies, ["new": 1, "work": 1])
    }

    func testUpdateNoteFromFilesystemReadFailurePreservesExistingTagsAndFrequencies() {
        let noteID = "Inbox/missing.md"
        let initial = makeIndex(
            notes: [
                noteID: NoteIndex(
                    id: noteID,
                    path: noteID,
                    title: "missing",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            tagFrequencies: ["work": 1]
        )

        let updated = LibraryIndexMutator.updateNoteFromFilesystem(
            index: initial,
            noteID: noteID,
            filesystemData: .init(modified: Date(timeIntervalSince1970: 200)),
            libraryURL: URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        )

        XCTAssertEqual(updated.notes[noteID]?.tags, ["work"])
        XCTAssertEqual(updated.tagFrequencies, ["work": 1])
    }

    func testDeleteNoteDecrementsTagFrequenciesAndRemovesZeroes() {
        let deleteID = "Inbox/delete.md"
        let keepID = "Inbox/keep.md"

        let initial = makeIndex(
            notes: [
                deleteID: NoteIndex(
                    id: deleteID,
                    path: deleteID,
                    title: "delete",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["unique", "work"]
                ),
                keepID: NoteIndex(
                    id: keepID,
                    path: keepID,
                    title: "keep",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [deleteID, keepID])
            ],
            tagFrequencies: ["unique": 1, "work": 2]
        )

        let updated = LibraryIndexMutator.deleteNote(
            index: initial,
            noteID: deleteID,
            collectionID: "Inbox"
        )

        XCTAssertNil(updated.notes[deleteID])
        XCTAssertEqual(updated.tagFrequencies, ["work": 1])
    }

    func testDeleteCollectionDecrementsFrequenciesForAllRemovedNotes() {
        let trashA = "Trash/a.md"
        let trashB = "Trash/b.md"
        let inboxX = "Inbox/x.md"

        let initial = makeIndex(
            notes: [
                trashA: NoteIndex(
                    id: trashA,
                    path: trashA,
                    title: "a",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["trash", "work"]
                ),
                trashB: NoteIndex(
                    id: trashB,
                    path: trashB,
                    title: "b",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["temp", "work"]
                ),
                inboxX: NoteIndex(
                    id: inboxX,
                    path: inboxX,
                    title: "x",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Trash": CollectionIndex(id: "Trash", noteIDs: [trashA, trashB]),
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [inboxX])
            ],
            tagFrequencies: ["trash": 1, "temp": 1, "work": 3]
        )

        let updated = LibraryIndexMutator.deleteCollection(
            index: initial,
            collectionID: "Trash"
        )

        XCTAssertNil(updated.notes[trashA])
        XCTAssertNil(updated.notes[trashB])
        XCTAssertEqual(updated.tagFrequencies, ["work": 1])
    }

    func testRenameNotePreservesTagsAndFrequencyMap() {
        let oldID = "Inbox/old.md"
        let otherID = "Inbox/other.md"

        let initial = makeIndex(
            notes: [
                oldID: NoteIndex(
                    id: oldID,
                    path: oldID,
                    title: "old",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["work", "x"]
                ),
                otherID: NoteIndex(
                    id: otherID,
                    path: otherID,
                    title: "other",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [oldID, otherID])
            ],
            tagFrequencies: ["work": 2, "x": 1]
        )

        let updated = LibraryIndexMutator.renameNote(
            index: initial,
            oldID: oldID,
            newID: "Inbox/new.md"
        )

        XCTAssertNil(updated.notes[oldID])
        XCTAssertEqual(updated.notes["Inbox/new.md"]?.tags, ["work", "x"])
        XCTAssertEqual(updated.tagFrequencies, ["work": 2, "x": 1])
    }

    func testReconcilerModifiedEventWithLibraryURLUpdatesTagsAndFrequencies() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let noteID = "Inbox/reconcile.md"
        try writeMarkdown("body #work #new", to: noteID, in: libraryURL)

        let initial = makeIndex(
            notes: [
                noteID: NoteIndex(
                    id: noteID,
                    path: noteID,
                    title: "reconcile",
                    modified: Date(timeIntervalSince1970: 1),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            tagFrequencies: ["work": 1]
        )

        let result = await LibraryIndexReconciler.applyEvents(
            [.modified(noteID: noteID)],
            to: initial,
            libraryURL: libraryURL
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.index.notes[noteID]?.tags, ["new", "work"])
        XCTAssertEqual(result.index.tagFrequencies, ["new": 1, "work": 1])
    }

    func testReconcilerMetadataOnlyModifiedDoesNotReparseTags() async {
        let noteID = "Inbox/no-parse.md"

        let initial = makeIndex(
            notes: [
                noteID: NoteIndex(
                    id: noteID,
                    path: noteID,
                    title: "no-parse",
                    modified: Date(timeIntervalSince1970: 1),
                    pinned: false,
                    tags: ["work"]
                )
            ],
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            tagFrequencies: ["work": 1]
        )

        let provider: @Sendable (String) -> (modified: Date, title: String)? = { query in
            guard query == noteID else { return nil }
            return (Date(timeIntervalSince1970: 2), "no-parse")
        }

        let result = await LibraryIndexReconciler.applyEvents(
            [.modified(noteID: noteID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.index.notes[noteID]?.tags, ["work"])
        XCTAssertEqual(result.index.tagFrequencies, ["work": 1])
    }

    // MARK: - Helpers

    private func makeIndex(
        notes: [String: NoteIndex] = [:],
        collections: [String: CollectionIndex] = [:],
        tagFrequencies: [String: Int] = [:]
    ) -> LibraryIndex {
        LibraryIndex(
            version: 1,
            libraryID: "test-library",
            lastUpdated: Date(timeIntervalSince1970: 0),
            collections: collections,
            notes: notes,
            tagFrequencies: tagFrequencies
        )
    }

    private func writeMarkdown(
        _ markdown: String,
        to noteID: String,
        in libraryURL: URL
    ) throws {
        let noteURL = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)
            .appendingPathComponent(noteID)

        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try markdown.write(to: noteURL, atomically: true, encoding: .utf8)
    }
}
