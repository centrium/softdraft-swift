import XCTest
@testable import SoftDraft

final class CanonicalPathTests: XCTestCase {

    func testDeriveCanonicalNoteIDForFileInsideCanonicalRoot() {
        let root = URL(fileURLWithPath: "/Users/matt/Libraries/Demo")
        let file = URL(fileURLWithPath: "/Users/matt/Libraries/Demo/collections/Inbox/Welcome.md")

        let noteID = deriveCanonicalNoteID(
            libraryRootURL: root,
            fileURL: file
        )

        XCTAssertEqual(noteID, "Inbox/Welcome.md")
    }

    func testDeriveCanonicalNoteIDIgnoresPathOutsideCanonicalRoot() {
        let root = URL(fileURLWithPath: "/Users/matt/Libraries/Demo")
        let file = URL(fileURLWithPath: "/private/Users/matt/Libraries/Demo/collections/Inbox/Welcome.md")

        let noteID = deriveCanonicalNoteID(
            libraryRootURL: root,
            fileURL: file
        )

        XCTAssertNil(noteID)
    }

    func testValidateNewLibraryRootLocationRejectsOutsideHomeDirectory() {
        let outsideHome = URL(fileURLWithPath: "/tmp/SoftDraftLibrary")
        let error = validateNewLibraryRootLocation(outsideHome)

        XCTAssertNotNil(error)
    }

    @MainActor
    func testSetActiveLibraryStoresStandardizedCanonicalRoot() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let nonCanonical = libraryURL
            .appendingPathComponent("collections", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)

        let manager = LibraryManager()
        await manager.setActiveLibrary(nonCanonical)

        XCTAssertEqual(
            manager.activeLibraryURL?.path,
            nonCanonical.standardizedFileURL.path
        )
    }
}
