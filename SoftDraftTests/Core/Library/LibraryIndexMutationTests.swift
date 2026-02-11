//
//  LibraryIndexMutationTests.swift
//  SoftDraftTests
//
//  Created by Matt Adams on 10/02/2026.
//

import XCTest
@testable import SoftDraft

final class LibraryIndexMutationTests: XCTestCase {

    func testCreateNoteUpdatesLibraryIndex() {
        let baseline = Date(timeIntervalSince1970: 0)
        let initial = makeIndex(
            lastUpdated: baseline,
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [])
            ],
            notes: [:]
        )

        let updated = LibraryIndexMutator.createNote(
            index: initial,
            noteID: "Inbox/hello.md",
            title: "Hello",
            collectionID: "Inbox"
        )

        XCTAssertNotNil(updated.notes["Inbox/hello.md"])
        XCTAssertEqual(updated.collections["Inbox"]?.noteIDs, ["Inbox/hello.md"])
        XCTAssertTrue(updated.lastUpdated > baseline)
        XCTAssertEqual(updated.notes["Inbox/hello.md"]?.pinned, false)

        XCTAssertEqual(updated.collections.keys.sorted(), ["Inbox"])

        assertInvariants(updated)
    }

    func testDeleteNoteUpdatesLibraryIndex() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/a.md", "Inbox/b.md"]
                ),
                "Ideas": CollectionIndex(
                    id: "Ideas",
                    noteIDs: ["Ideas/x.md"]
                )
            ],
            notes: [
                "Inbox/a.md": makeNote(id: "Inbox/a.md", title: "A"),
                "Inbox/b.md": makeNote(id: "Inbox/b.md", title: "B"),
                "Ideas/x.md": makeNote(id: "Ideas/x.md", title: "X")
            ]
        )

        let updated = LibraryIndexMutator.deleteNote(
            index: initial,
            noteID: "Inbox/a.md",
            collectionID: "Inbox"
        )

        XCTAssertNil(updated.notes["Inbox/a.md"])
        XCTAssertEqual(updated.collections["Inbox"]?.noteIDs, ["Inbox/b.md"])
        XCTAssertNotNil(updated.notes["Inbox/b.md"])
        XCTAssertNotNil(updated.notes["Ideas/x.md"])

        assertInvariants(updated)
    }

    func testRenameNoteWithinCollectionUpdatesLibraryIndex() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/old.md"]
                )
            ],
            notes: [
                "Inbox/old.md": makeNote(
                    id: "Inbox/old.md",
                    title: "Title"
                )
            ]
        )

        let updated = LibraryIndexMutator.renameNote(
            index: initial,
            oldID: "Inbox/old.md",
            newID: "Inbox/new.md"
        )

        XCTAssertNil(updated.notes["Inbox/old.md"])
        XCTAssertNotNil(updated.notes["Inbox/new.md"])
        XCTAssertEqual(updated.notes["Inbox/new.md"]?.title, "Title")
        XCTAssertEqual(updated.notes["Inbox/new.md"]?.path, "Inbox/new.md")
        XCTAssertEqual(updated.collections["Inbox"]?.noteIDs, ["Inbox/new.md"])

        assertInvariants(updated)
    }

    func testRenameNotePreservesPinned() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/old.md"]
                )
            ],
            notes: [
                "Inbox/old.md": makeNote(
                    id: "Inbox/old.md",
                    title: "Title",
                    pinned: true
                )
            ]
        )

        let updated = LibraryIndexMutator.renameNote(
            index: initial,
            oldID: "Inbox/old.md",
            newID: "Inbox/new.md"
        )

        XCTAssertEqual(updated.notes["Inbox/new.md"]?.pinned, true)
        assertInvariants(updated)
    }

    func testRenameNoteMovesBetweenCollections() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/old.md", "Inbox/keep.md"]
                ),
                "Ideas": CollectionIndex(
                    id: "Ideas",
                    noteIDs: []
                )
            ],
            notes: [
                "Inbox/old.md": makeNote(
                    id: "Inbox/old.md",
                    title: "Title"
                ),
                "Inbox/keep.md": makeNote(
                    id: "Inbox/keep.md",
                    title: "Keep"
                )
            ]
        )

        let updated = LibraryIndexMutator.renameNote(
            index: initial,
            oldID: "Inbox/old.md",
            newID: "Ideas/new.md"
        )

        XCTAssertNil(updated.notes["Inbox/old.md"])
        XCTAssertNotNil(updated.notes["Ideas/new.md"])
        XCTAssertEqual(updated.notes["Ideas/new.md"]?.title, "Title")
        XCTAssertEqual(updated.notes["Ideas/new.md"]?.path, "Ideas/new.md")
        XCTAssertEqual(updated.collections["Inbox"]?.noteIDs, ["Inbox/keep.md"])
        XCTAssertEqual(updated.collections["Ideas"]?.noteIDs, ["Ideas/new.md"])

        assertInvariants(updated)
    }

    func testMoveNotePreservesPinned() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/old.md"]
                ),
                "Ideas": CollectionIndex(
                    id: "Ideas",
                    noteIDs: []
                )
            ],
            notes: [
                "Inbox/old.md": makeNote(
                    id: "Inbox/old.md",
                    title: "Title",
                    pinned: true
                )
            ]
        )

        let updated = LibraryIndexMutator.renameNote(
            index: initial,
            oldID: "Inbox/old.md",
            newID: "Ideas/new.md"
        )

        XCTAssertEqual(updated.notes["Ideas/new.md"]?.pinned, true)
        assertInvariants(updated, allowEmptyCollections: ["Inbox"])
    }

    func testCreateCollectionUpdatesLibraryIndex() {
        let baseline = Date(timeIntervalSince1970: 0)
        let initial = makeIndex(lastUpdated: baseline)

        let updated = LibraryIndexMutator.createCollection(
            index: initial,
            collectionID: "Journal"
        )

        XCTAssertNotNil(updated.collections["Journal"])
        XCTAssertEqual(updated.collections["Journal"]?.noteIDs, [])
        XCTAssertTrue(updated.lastUpdated > baseline)

        assertInvariants(updated, allowEmptyCollections: ["Journal"])
    }

    func testRenameCollectionUpdatesLibraryIndex() {
        let initial = makeIndex(
            collections: [
                "Old": CollectionIndex(
                    id: "Old",
                    noteIDs: ["Old/a.md", "Old/b.md"]
                ),
                "Other": CollectionIndex(
                    id: "Other",
                    noteIDs: ["Other/z.md"]
                )
            ],
            notes: [
                "Old/a.md": makeNote(id: "Old/a.md", title: "A"),
                "Old/b.md": makeNote(id: "Old/b.md", title: "B"),
                "Other/z.md": makeNote(id: "Other/z.md", title: "Z")
            ]
        )

        let updated = LibraryIndexMutator.renameCollection(
            index: initial,
            oldID: "Old",
            newID: "New"
        )

        XCTAssertNil(updated.collections["Old"])
        XCTAssertNotNil(updated.collections["New"])

        let newNoteIDs = Set(updated.collections["New"]?.noteIDs ?? [])
        XCTAssertEqual(newNoteIDs, ["New/a.md", "New/b.md"])

        XCTAssertNil(updated.notes["Old/a.md"])
        XCTAssertNil(updated.notes["Old/b.md"])
        XCTAssertNotNil(updated.notes["New/a.md"])
        XCTAssertNotNil(updated.notes["New/b.md"])
        XCTAssertEqual(updated.notes["New/a.md"]?.path, "New/a.md")
        XCTAssertEqual(updated.notes["New/b.md"]?.path, "New/b.md")

        XCTAssertEqual(updated.collections["Other"]?.noteIDs, ["Other/z.md"])
        XCTAssertNotNil(updated.notes["Other/z.md"])

        assertInvariants(updated)
    }

    func testRenameCollectionPreservesPinned() {
        let initial = makeIndex(
            collections: [
                "Old": CollectionIndex(
                    id: "Old",
                    noteIDs: ["Old/a.md", "Old/b.md"]
                )
            ],
            notes: [
                "Old/a.md": makeNote(id: "Old/a.md", title: "A", pinned: true),
                "Old/b.md": makeNote(id: "Old/b.md", title: "B", pinned: false)
            ]
        )

        let updated = LibraryIndexMutator.renameCollection(
            index: initial,
            oldID: "Old",
            newID: "New"
        )

        XCTAssertEqual(updated.notes["New/a.md"]?.pinned, true)
        XCTAssertEqual(updated.notes["New/b.md"]?.pinned, false)
        assertInvariants(updated)
    }

    func testDeleteCollectionRemovesNotes() {
        let initial = makeIndex(
            collections: [
                "Trash": CollectionIndex(
                    id: "Trash",
                    noteIDs: ["Trash/a.md", "Trash/b.md"]
                ),
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/x.md"]
                )
            ],
            notes: [
                "Trash/a.md": makeNote(id: "Trash/a.md", title: "A"),
                "Trash/b.md": makeNote(id: "Trash/b.md", title: "B"),
                "Inbox/x.md": makeNote(id: "Inbox/x.md", title: "X")
            ]
        )

        let updated = LibraryIndexMutator.deleteCollection(
            index: initial,
            collectionID: "Trash"
        )

        XCTAssertNil(updated.collections["Trash"])
        XCTAssertNil(updated.notes["Trash/a.md"])
        XCTAssertNil(updated.notes["Trash/b.md"])

        XCTAssertNotNil(updated.collections["Inbox"])
        XCTAssertNotNil(updated.notes["Inbox/x.md"])

        assertInvariants(updated)
    }

    func testTogglePinUpdatesLibraryIndex() {
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(
                    id: "Inbox",
                    noteIDs: ["Inbox/a.md"]
                )
            ],
            notes: [
                "Inbox/a.md": makeNote(id: "Inbox/a.md", title: "A", pinned: false)
            ]
        )

        let pinned = LibraryIndexMutator.togglePin(
            index: initial,
            noteID: "Inbox/a.md"
        )

        XCTAssertEqual(pinned.notes["Inbox/a.md"]?.pinned, true)

        let unpinned = LibraryIndexMutator.togglePin(
            index: pinned,
            noteID: "Inbox/a.md"
        )

        XCTAssertEqual(unpinned.notes["Inbox/a.md"]?.pinned, false)
        assertInvariants(unpinned)
    }

    private func makeIndex(
        lastUpdated: Date = Date(timeIntervalSince1970: 0),
        collections: [String: CollectionIndex] = [:],
        notes: [String: NoteIndex] = [:]
    ) -> LibraryIndex {
        LibraryIndex(
            version: 1,
            libraryID: "test-library",
            lastUpdated: lastUpdated,
            collections: collections,
            notes: notes
        )
    }

    private func makeNote(
        id: String,
        title: String,
        modified: Date = Date(timeIntervalSince1970: 100),
        pinned: Bool = false
    ) -> NoteIndex {
        NoteIndex(
            id: id,
            path: id,
            title: title,
            modified: modified,
            pinned: pinned
        )
    }

    private func assertInvariants(
        _ index: LibraryIndex,
        allowEmptyCollections: Set<String> = []
    ) {
        var allCollectionNoteIDs: [String] = []

        for (collectionID, collection) in index.collections {
            if collection.noteIDs.isEmpty {
                XCTAssertTrue(
                    allowEmptyCollections.contains(collectionID),
                    "Unexpected empty collection: \(collectionID)"
                )
            }
            allCollectionNoteIDs.append(contentsOf: collection.noteIDs)
        }

        let uniqueCollectionNoteIDs = Set(allCollectionNoteIDs)
        XCTAssertEqual(
            uniqueCollectionNoteIDs.count,
            allCollectionNoteIDs.count,
            "Duplicate note IDs across collections"
        )

        for noteID in allCollectionNoteIDs {
            XCTAssertNotNil(
                index.notes[noteID],
                "Collection references missing note: \(noteID)"
            )
        }

        let indexNoteIDs = Set(index.notes.keys)
        XCTAssertEqual(
            indexNoteIDs,
            uniqueCollectionNoteIDs,
            "Notes are orphaned or missing from collections"
        )
    }
}
