import XCTest
@testable import SoftDraft

@MainActor
final class LibraryIndexStateMigrationTests: XCTestCase {

    func testLoadingIndexWithoutStateDefaultsToDraftingAndPersistsMigration() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let created = try NoteStore.create(
            libraryURL: libraryURL,
            collection: "Inbox",
            title: "Legacy"
        )

        try writeLegacyIndex(
            libraryURL: libraryURL,
            noteID: created.summary.id,
            stateRawValue: nil
        )

        let manager = LibraryManager()
        let selection = SelectionModel()
        manager.bind(selection: selection)

        await manager.setActiveLibrary(libraryURL)

        XCTAssertEqual(manager.libraryIndex?.notes[created.summary.id]?.state, .drafting)

        let persistedURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        let persistedData = try Data(contentsOf: persistedURL)
        let persistedText = String(decoding: persistedData, as: UTF8.self)
        XCTAssertTrue(persistedText.contains("\"state\""))
    }

    func testLoadingLegacyStateRawValueMigratesToNewState() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let created = try NoteStore.create(
            libraryURL: libraryURL,
            collection: "Inbox",
            title: "Legacy"
        )

        try writeLegacyIndex(
            libraryURL: libraryURL,
            noteID: created.summary.id,
            stateRawValue: "completed"
        )

        let manager = LibraryManager()
        let selection = SelectionModel()
        manager.bind(selection: selection)

        await manager.setActiveLibrary(libraryURL)

        XCTAssertEqual(manager.libraryIndex?.notes[created.summary.id]?.state, .finished)
    }

    private func writeLegacyIndex(
        libraryURL: URL,
        noteID: String,
        stateRawValue: String?
    ) throws {
        let indexURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        try FileManager.default.createDirectory(
            at: indexURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var note: [String: Any] = [
            "id": noteID,
            "path": noteID,
            "title": "Legacy",
            "modified": Date().timeIntervalSinceReferenceDate,
            "pinned": false,
            "tags": []
        ]

        if let stateRawValue {
            note["state"] = stateRawValue
        }

        let payload: [String: Any] = [
            "version": 1,
            "libraryID": "legacy-library",
            "lastUpdated": Date().timeIntervalSinceReferenceDate,
            "collections": [
                "Inbox": [
                    "id": "Inbox",
                    "noteIDs": [noteID]
                ]
            ],
            "notes": [
                noteID: note
            ],
            "tagFrequencies": [String: Int]()
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: indexURL, options: .atomic)
    }
}
