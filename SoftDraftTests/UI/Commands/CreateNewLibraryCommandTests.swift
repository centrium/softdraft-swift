import XCTest
@testable import SoftDraft

@MainActor
final class CreateNewLibraryCommandTests: XCTestCase {

    func testCreateInitialLibraryStructureCreatesInboxWelcomeAndFinishedState() async throws {
        let rootURL = try makeEmptyDirectory()

        try await createInitialLibraryStructure(at: rootURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("assets").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("collections").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("collections/Inbox").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("collections/Inbox/Welcome.md").path))

        let markdown = try String(
            contentsOf: rootURL.appendingPathComponent("collections/Inbox/Welcome.md"),
            encoding: .utf8
        )
        XCTAssertTrue(markdown.contains("Welcome to Your New Library"))
        XCTAssertTrue(markdown.contains("Use ⌘K to run commands."))

        let index = try readPersistedIndex(libraryURL: rootURL)
        XCTAssertEqual(index.notes["Inbox/Welcome.md"]?.state, .finished)
        XCTAssertEqual(index.collections["Inbox"]?.noteIDs, ["Inbox/Welcome.md"])
    }

    func testOpeningNewLibraryShowsLandingWithoutAutoOpeningWelcome() async throws {
        let rootURL = try makeEmptyDirectory()
        try await createInitialLibraryStructure(at: rootURL)

        let manager = LibraryManager()
        let selection = SelectionModel()
        let uiState = UIState()
        let previewSession = NotePreviewSessionController()

        selection.configurePreviewModeResolver(
            resolve: { noteID in
                let noteState = manager.noteState(noteID: noteID)
                let surface = uiState.resolveInitialSurface(
                    for: noteID,
                    state: noteState,
                    sessionState: previewSession
                )
                return surface == .preview
            },
            applyPreview: { isPreview in
                uiState.isPreviewModeEnabled = isPreview
            },
            resolveText: { noteID in
                guard let libraryURL = manager.currentLibraryURL else { return "" }
                return (try? NoteStore.load(
                    libraryURL: libraryURL,
                    noteID: noteID
                )) ?? ""
            },
            applyText: { text in
                manager.currentNoteText = text
            }
        )

        manager.bind(selection: selection)
        await manager.setActiveLibrary(rootURL)

        XCTAssertEqual(selection.selectedCollectionID, "Inbox")
        XCTAssertNil(selection.selectedNoteID)
        XCTAssertEqual(manager.currentNoteText, "")
        XCTAssertFalse(uiState.isPreviewModeEnabled)
        XCTAssertEqual(manager.noteState(noteID: "Inbox/Welcome.md"), .finished)
    }

    private func makeEmptyDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func readPersistedIndex(libraryURL: URL) throws -> LibraryIndex {
        let persistedURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        let data = try Data(contentsOf: persistedURL)
        return try JSONDecoder().decode(LibraryIndex.self, from: data)
    }
}
