//
//  LibraryIndexReconcilerTests.swift
//  SoftDraftTests
//
//  Created by Matt Adams on 11/02/2026.
//

import Foundation
import XCTest
@testable import SoftDraft

final class LibraryIndexReconcilerTests: XCTestCase {

    func testModifiedPreservesPinnedAndTitle() async {
        let noteID = "Inbox/pinned.md"
        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            notes: [
                noteID: makeNote(
                    id: noteID,
                    title: "Custom Title",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: true
                )
            ]
        )

        let provider = makeMetadataProvider([
            noteID: (modified: Date(timeIntervalSince1970: 200), title: "pinned")
        ])

        let result = await LibraryIndexReconciler.applyEvents(
            [.modified(noteID: noteID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.index.notes[noteID]?.pinned, true)
        XCTAssertEqual(result.index.notes[noteID]?.title, "Custom Title")
        XCTAssertEqual(
            result.index.notes[noteID]?.modified,
            Date(timeIntervalSince1970: 200)
        )
    }

    func testRenamePreservesPinned() async {
        let oldID = "Inbox/old.md"
        let newID = "Inbox/new.md"

        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [oldID])
            ],
            notes: [
                oldID: makeNote(
                    id: oldID,
                    title: "Old",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: true
                )
            ]
        )

        let provider = makeMetadataProvider([
            newID: (modified: Date(timeIntervalSince1970: 300), title: "new")
        ])

        let result = await LibraryIndexReconciler.applyEvents(
            [.renamed(from: oldID, to: newID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertNil(result.index.notes[oldID])
        XCTAssertEqual(result.index.notes[newID]?.pinned, true)
        XCTAssertEqual(result.index.notes[newID]?.title, "new")
        XCTAssertEqual(result.index.collections["Inbox"]?.noteIDs, [newID])
    }

    func testMovePreservesPinned() async {
        let oldID = "Inbox/old.md"
        let newID = "Work/moved.md"

        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [oldID]),
                "Work": CollectionIndex(id: "Work", noteIDs: [])
            ],
            notes: [
                oldID: makeNote(
                    id: oldID,
                    title: "Old",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: true
                )
            ]
        )

        let provider = makeMetadataProvider([
            newID: (modified: Date(timeIntervalSince1970: 400), title: "moved")
        ])

        let result = await LibraryIndexReconciler.applyEvents(
            [.renamed(from: oldID, to: newID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertNil(result.index.notes[oldID])
        XCTAssertEqual(result.index.notes[newID]?.pinned, true)
        XCTAssertEqual(result.index.collections["Work"]?.noteIDs, [newID])
        XCTAssertEqual(result.index.collections["Inbox"]?.noteIDs, [])
    }

    func testDeleteRemovesPinned() async {
        let noteID = "Inbox/delete.md"

        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            notes: [
                noteID: makeNote(
                    id: noteID,
                    title: "Delete",
                    pinned: true
                )
            ]
        )

        let provider = makeMetadataProvider([:])

        let result = await LibraryIndexReconciler.applyEvents(
            [.deleted(noteID: noteID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertNil(result.index.notes[noteID])
        XCTAssertEqual(result.index.collections["Inbox"]?.noteIDs, [])
    }

    func testAddedDefaultsPinnedFalse() async {
        let noteID = "Inbox/added.md"
        let initial = makeIndex()

        let provider = makeMetadataProvider([
            noteID: (modified: Date(timeIntervalSince1970: 500), title: "added")
        ])

        let result = await LibraryIndexReconciler.applyEvents(
            [.added(noteID: noteID)],
            to: initial,
            metadataProvider: provider
        )

        XCTAssertEqual(result.index.notes[noteID]?.pinned, false)
        XCTAssertEqual(result.index.collections["Inbox"]?.noteIDs, [noteID])
    }

    func testCatchUpDiffPreservesPinnedMetadata() {
        let noteID = "Inbox/catchup.md"

        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [noteID])
            ],
            notes: [
                noteID: makeNote(
                    id: noteID,
                    title: "Pinned Title",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: true
                )
            ]
        )

        let snapshot = LibraryIndexReconciler.FilesystemSnapshot(
            collections: ["Inbox"],
            notes: [
                noteID: LibraryIndexReconciler.NoteSnapshot(
                    modified: Date(timeIntervalSince1970: 250),
                    filename: "catchup.md",
                    title: "Pinned Title"
                )
            ]
        )

        let result = LibraryIndexReconciler.reconcileAgainstSnapshot(
            snapshot: snapshot,
            index: initial
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.index.notes[noteID]?.pinned, true)
        XCTAssertEqual(result.index.notes[noteID]?.title, "Pinned Title")
        XCTAssertEqual(
            result.index.notes[noteID]?.modified,
            Date(timeIntervalSince1970: 250)
        )
    }

    func testCatchUpRenamePreservesPinnedWhenFilenameChanges() {
        let oldID = "Inbox/old.md"
        let newID = "Inbox/new-name.md"

        let initial = makeIndex(
            collections: [
                "Inbox": CollectionIndex(id: "Inbox", noteIDs: [oldID])
            ],
            notes: [
                oldID: makeNote(
                    id: oldID,
                    title: "Old Title",
                    modified: Date(timeIntervalSince1970: 100),
                    pinned: true
                )
            ]
        )

        let snapshot = LibraryIndexReconciler.FilesystemSnapshot(
            collections: ["Inbox"],
            notes: [
                newID: LibraryIndexReconciler.NoteSnapshot(
                    modified: Date(timeIntervalSince1970: 100),
                    filename: "new-name.md",
                    title: "new-name"
                )
            ]
        )

        let result = LibraryIndexReconciler.reconcileAgainstSnapshot(
            snapshot: snapshot,
            index: initial
        )

        XCTAssertTrue(result.changed)
        XCTAssertNil(result.index.notes[oldID])
        XCTAssertEqual(result.index.notes[newID]?.pinned, true)
        XCTAssertEqual(result.index.notes[newID]?.title, "new-name")
        XCTAssertEqual(result.index.collections["Inbox"]?.noteIDs, [newID])
    }

    private func makeIndex(
        collections: [String: CollectionIndex] = [:],
        notes: [String: NoteIndex] = [:]
    ) -> LibraryIndex {
        LibraryIndex(
            version: 1,
            libraryID: "test-library",
            lastUpdated: Date(timeIntervalSince1970: 0),
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

    private func makeMetadataProvider(
        _ values: [String: (modified: Date, title: String)]
    ) -> (String) -> (modified: Date, title: String)? {
        { noteID in
            values[noteID]
        }
    }
}
