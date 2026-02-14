import XCTest
@testable import SoftDraft

@MainActor
final class NoteStateFilteringTests: XCTestCase {

    func testNilFilterReturnsAllNotes() {
        let notes = makeNotes()

        let filtered = NoteStateFiltering.filteredNotes(
            from: notes,
            stateFilter: nil
        )

        XCTAssertEqual(filtered.map(\.id), notes.map(\.id))
    }

    func testStateFilterReturnsMatchingSubset() {
        let notes = makeNotes()

        let filtered = NoteStateFiltering.filteredNotes(
            from: notes,
            stateFilter: .refining
        )

        XCTAssertEqual(filtered.map(\.id), ["Inbox/refining.md"])
    }

    func testSearchResultsAndStateFilterComposeCorrectly() {
        let notesByID = Dictionary(uniqueKeysWithValues: makeNotes().map { ($0.id, $0) })
        let searchResultIDs = [
            "Inbox/drafting.md",
            "Inbox/finished.md",
            "Inbox/refining.md"
        ]

        let filteredIDs = NoteStateFiltering.filteredByState(
            searchResultIDs,
            stateFilter: .finished
        ) { noteID in
            notesByID[noteID]?.state ?? .drafting
        }

        XCTAssertEqual(filteredIDs, ["Inbox/finished.md"])
    }

    func testPinnedNotesAreExcludedWhenStateMismatch() {
        let notes = makeNotes()

        let filtered = NoteStateFiltering.filteredNotes(
            from: notes,
            stateFilter: .drafting
        )
        let pinned = filtered.filter(\.pinned)

        XCTAssertEqual(pinned.map(\.id), ["Inbox/drafting.md"])
        XCTAssertFalse(filtered.contains(where: { $0.id == "Inbox/refining.md" }))
    }

    func testClearingFilterReturnsFullList() {
        let notes = makeNotes()

        let refiningOnly = NoteStateFiltering.filteredNotes(
            from: notes,
            stateFilter: .refining
        )
        XCTAssertEqual(refiningOnly.map(\.id), ["Inbox/refining.md"])

        let cleared = NoteStateFiltering.filteredNotes(
            from: notes,
            stateFilter: nil
        )
        XCTAssertEqual(cleared.map(\.id), notes.map(\.id))
    }

    private func makeNotes() -> [NoteSummary] {
        let now = Date(timeIntervalSince1970: 1_000)
        return [
            NoteSummary(
                id: "Inbox/drafting.md",
                name: "drafting",
                title: "Drafting",
                relativeDir: "Inbox",
                modifiedAt: now,
                pinned: true,
                state: .drafting
            ),
            NoteSummary(
                id: "Inbox/refining.md",
                name: "refining",
                title: "Refining",
                relativeDir: "Inbox",
                modifiedAt: now.addingTimeInterval(-10),
                pinned: true,
                state: .refining
            ),
            NoteSummary(
                id: "Inbox/finished.md",
                name: "finished",
                title: "Finished",
                relativeDir: "Inbox",
                modifiedAt: now.addingTimeInterval(-20),
                pinned: false,
                state: .finished
            )
        ]
    }
}
