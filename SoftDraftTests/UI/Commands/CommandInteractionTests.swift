import XCTest
@testable import SoftDraft

@MainActor
final class CommandInteractionTests: XCTestCase {

    func testFocusCycleCommandsWrapCorrectly() async throws {
        let setup = try await makeContext()

        setup.uiState.activeFocusRegion = .sidebar
        await cycleFocusForwardCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .notesList)

        setup.uiState.activeFocusRegion = .notesList
        await cycleFocusForwardCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .editor)

        setup.uiState.activeFocusRegion = .editor
        await cycleFocusForwardCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .sidebar)

        setup.uiState.activeFocusRegion = .sidebar
        await cycleFocusBackwardCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .editor)
    }

    func testFocusEditorCommandRequiresSelectionAndTargetsEditor() async throws {
        let setup = try await makeContext()

        await focusEditorCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .sidebar)

        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Focus Target",
            markdown: "# Focus Target\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)
        setup.uiState.isPreviewModeEnabled = true

        await focusEditorCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.requestedFocusRegion, .editor)
        XCTAssertFalse(setup.uiState.isPreviewModeEnabled)
    }

    func testSidebarModeCommandsSetExplicitModesAndStayStable() async throws {
        let setup = try await makeContext()

        await showTagsSidebarCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.sidebarMode, .tags)
        await showTagsSidebarCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.sidebarMode, .tags)

        await showCollectionsSidebarCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.sidebarMode, .collections)
        await showCollectionsSidebarCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.sidebarMode, .collections)
    }

    func testCollectionListExpandCollapseCommandsAreStableAndSafe() async throws {
        let setup = try await makeContext()

        setup.uiState.sidebarMode = .collections
        setup.uiState.isCollectionsListExpanded = false

        await expandCollectionsListCommand.perform(setup.context)
        XCTAssertTrue(setup.uiState.isCollectionsListExpanded)
        await expandCollectionsListCommand.perform(setup.context)
        XCTAssertTrue(setup.uiState.isCollectionsListExpanded)

        await collapseCollectionsListCommand.perform(setup.context)
        XCTAssertFalse(setup.uiState.isCollectionsListExpanded)
        await collapseCollectionsListCommand.perform(setup.context)
        XCTAssertFalse(setup.uiState.isCollectionsListExpanded)

        setup.uiState.sidebarMode = .tags
        setup.uiState.isCollectionsListExpanded = false
        await expandCollectionsListCommand.perform(setup.context)
        XCTAssertFalse(setup.uiState.isCollectionsListExpanded)

        setup.uiState.isCollectionsListExpanded = true
        await collapseCollectionsListCommand.perform(setup.context)
        XCTAssertTrue(setup.uiState.isCollectionsListExpanded)
    }

    func testRenameNotePreservesTagsAndPinning() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Alpha",
            markdown: "# Alpha\n\nBody #work"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.manager.togglePin(noteID: noteID)
        setup.manager.setNoteState(noteID: noteID, state: .refining)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)

        let newID = try NoteStore.rename(
            libraryURL: setup.libraryURL,
            oldID: noteID,
            newTitle: "Renamed Note"
        )
        setup.manager.replaceNoteID(oldID: noteID, newID: newID)

        let renamedID = setup.manager.libraryIndex?.notes.keys.first { $0.hasPrefix("Inbox/renamed-note") }
        XCTAssertNotNil(renamedID)
        XCTAssertNil(setup.manager.libraryIndex?.notes[noteID])
        XCTAssertEqual(setup.manager.libraryIndex?.notes[renamedID ?? ""]?.tags, ["work"])
        XCTAssertEqual(setup.manager.libraryIndex?.notes[renamedID ?? ""]?.pinned, true)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[renamedID ?? ""]?.state, .refining)
    }

    func testDeleteNoteCommandRemovesIndexEntry() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Delete Me",
            markdown: "# Delete Me\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)

        await deleteNoteCommand.perform(
            setup.context,
            arguments: CommandArguments(noteID: noteID)
        )

        XCTAssertNil(setup.manager.libraryIndex?.notes[noteID])
    }

    func testTogglePinCommandPersistsStateToDisk() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Pinned",
            markdown: "# Pinned\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectNote(noteID)

        await togglePinCommand.perform(
            setup.context,
            arguments: CommandArguments(noteID: noteID)
        )

        let persisted = try readPersistedIndex(libraryURL: setup.libraryURL)
        XCTAssertEqual(persisted.notes[noteID]?.pinned, true)
    }

    func testMoveCommandPreservesNoteState() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Mover",
            markdown: "# Mover\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)

        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)
        setup.manager.setNoteState(noteID: noteID, state: .refining)

        await confirmMoveNoteCommand.perform(
            setup.context,
            arguments: CommandArguments(
                noteID: noteID,
                collectionID: "Work"
            )
        )

        let movedID = setup.manager.libraryIndex?.notes.keys.first { $0.hasPrefix("Work/") }
        XCTAssertNotNil(movedID)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[movedID ?? ""]?.state, .refining)
    }

    func testTagCommandsSelectAndRemoveTag() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Tagged",
            markdown: "# Tagged\n\nBody #work #idea"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)

        await selectTagCommand.perform(
            setup.context,
            arguments: CommandArguments(tagID: "work")
        )

        XCTAssertEqual(setup.uiState.sidebarMode, .tags)
        XCTAssertEqual(setup.manager.visibleTag, "work")

        await removeTagFromNoteCommand.perform(
            setup.context,
            arguments: CommandArguments(
                noteID: noteID,
                tagID: "work"
            )
        )

        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.tags, ["idea"])
    }

    func testCollectionCommandsCreateRenameAndDeleteSafely() async throws {
        let setup = try await makeContext()

        await createCollectionCommand.perform(setup.context)
        let created = setup.selection.selectedCollectionID
        XCTAssertNotNil(created)

        await renameCollectionCommand.perform(
            setup.context,
            arguments: CommandArguments(
                collectionID: created,
                textValue: "Projects"
            )
        )

        XCTAssertTrue(setup.manager.visibleCollections.contains("Projects"))

        await createNoteInCollectionCommand.perform(
            setup.context,
            arguments: CommandArguments(collectionID: "Projects")
        )
        XCTAssertTrue(setup.selection.selectedNoteID?.hasPrefix("Projects/") == true)

        await createCollectionCommand.perform(setup.context)
        let emptyCollection = setup.selection.selectedCollectionID
        XCTAssertNotNil(emptyCollection)

        await deleteCollectionCommand.perform(
            setup.context,
            arguments: CommandArguments(collectionID: emptyCollection)
        )
        XCTAssertFalse(setup.manager.visibleCollections.contains(emptyCollection ?? ""))
    }

    func testRevealNoteInFinderCommandIsSafeAndEnabledOnlyWithSelection() async throws {
        let setup = try await makeContext()

        XCTAssertFalse(revealNoteInFinderCommand.isEnabled(setup.context))
        await revealNoteInFinderCommand.perform(setup.context)

        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Reveal Target",
            markdown: "# Reveal Target\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)

        XCTAssertTrue(revealNoteInFinderCommand.isEnabled(setup.context))
        XCTAssertTrue(
            revealNoteInFinderCommand.isEnabled(
                setup.context,
                arguments: CommandArguments(noteID: noteID)
            )
        )
    }

    func testSetStateCommandPersistsAndIsIdempotentWhenInvalid() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Stateful",
            markdown: "# Stateful\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)

        await setStateCommand.perform(
            setup.context,
            arguments: CommandArguments(
                noteID: noteID,
                noteState: .finished
            )
        )
        await setStateCommand.perform(
            setup.context,
            arguments: CommandArguments(
                noteID: noteID,
                noteState: .finished
            )
        )
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .finished)

        let beforeLastUpdated = setup.manager.libraryIndex?.lastUpdated
        await setStateCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .finished)
        XCTAssertEqual(setup.manager.libraryIndex?.lastUpdated, beforeLastUpdated)

        let persisted = try readPersistedIndex(libraryURL: setup.libraryURL)
        XCTAssertEqual(persisted.notes[noteID]?.state, .finished)

        let reloadedManager = LibraryManager()
        let reloadedSelection = SelectionModel()
        reloadedManager.bind(selection: reloadedSelection)
        await reloadedManager.setActiveLibrary(setup.libraryURL)
        XCTAssertEqual(reloadedManager.libraryIndex?.notes[noteID]?.state, .finished)
    }

    func testCycleNoteStateCommandCyclesForwardAndWraps() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Cycle",
            markdown: "# Cycle\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)

        await cycleNoteStateCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .refining)

        await cycleNoteStateCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .finished)

        await cycleNoteStateCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .drafting)
    }

    func testCycleNoteStateFilterCommandCyclesForwardAndWraps() async throws {
        let setup = try await makeContext()

        XCTAssertNil(setup.uiState.noteStateFilter)

        await cycleNoteStateFilterCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.noteStateFilter, .drafting)

        await cycleNoteStateFilterCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.noteStateFilter, .refining)

        await cycleNoteStateFilterCommand.perform(setup.context)
        XCTAssertEqual(setup.uiState.noteStateFilter, .finished)

        await cycleNoteStateFilterCommand.perform(setup.context)
        XCTAssertNil(setup.uiState.noteStateFilter)
    }

    func testClearStateFilterCommandResetsToAllStates() async throws {
        let setup = try await makeContext()

        await setNoteStateFilterCommand.perform(
            setup.context,
            arguments: CommandArguments(noteState: .refining)
        )
        XCTAssertEqual(setup.uiState.noteStateFilter, .refining)

        await clearNoteStateFilterCommand.perform(setup.context)
        XCTAssertNil(setup.uiState.noteStateFilter)
    }

    func testDirectStateShortcutCommandsSetExpectedState() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Direct State",
            markdown: "# Direct State\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)

        await setNoteStateToRefiningCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .refining)

        await setNoteStateToFinishedCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .finished)

        await setNoteStateToDraftingCommand.perform(setup.context)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .drafting)
    }

    func testDuplicateCommandCopiesNoteState() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Source",
            markdown: "# Source\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(noteID)
        setup.manager.setNoteState(noteID: noteID, state: .refining)

        await duplicateNoteCommand.perform(
            setup.context,
            arguments: CommandArguments(noteID: noteID)
        )

        let duplicateID = setup.manager.libraryIndex?.notes.keys.first {
            $0 != noteID && $0.hasPrefix("Inbox/")
        }
        XCTAssertNotNil(duplicateID)
        XCTAssertEqual(setup.manager.libraryIndex?.notes[duplicateID ?? ""]?.state, .refining)
    }

    func testRebuildLibraryIndexPreservesNoteState() async throws {
        let setup = try await makeContext()
        let noteID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Persistent",
            markdown: "# Persistent\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)
        setup.manager.setNoteState(noteID: noteID, state: .finished)

        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)

        XCTAssertEqual(setup.manager.libraryIndex?.notes[noteID]?.state, .finished)
    }

    func testResolveInitialSurfaceUsesStateAndSessionRules() async throws {
        let uiState = UIState()
        let sessionState = NotePreviewSessionController()

        let drafting = NoteSummary(
            id: "Inbox/drafting.md",
            name: "drafting.md",
            title: "Drafting",
            relativeDir: "Inbox",
            modifiedAt: Date(),
            pinned: false,
            state: .drafting
        )
        let refining = NoteSummary(
            id: "Inbox/refining.md",
            name: "refining.md",
            title: "Refining",
            relativeDir: "Inbox",
            modifiedAt: Date(),
            pinned: false,
            state: .refining
        )
        let finished = NoteSummary(
            id: "Inbox/finished.md",
            name: "finished.md",
            title: "Finished",
            relativeDir: "Inbox",
            modifiedAt: Date(),
            pinned: false,
            state: .finished
        )

        XCTAssertEqual(
            uiState.resolveInitialSurface(for: drafting, sessionState: sessionState),
            .editor
        )
        XCTAssertEqual(
            uiState.resolveInitialSurface(for: refining, sessionState: sessionState),
            .editor
        )
        XCTAssertEqual(
            uiState.resolveInitialSurface(for: finished, sessionState: sessionState),
            .preview
        )

        sessionState.markPreviewShown(noteID: refining.id, state: .refining)
        XCTAssertEqual(
            uiState.resolveInitialSurface(for: refining, sessionState: sessionState),
            .preview
        )
    }

    func testPreviewCommandMarksOnlyRefiningNotesInSession() async throws {
        let setup = try await makeContext()
        let refiningID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Refining Note",
            markdown: "# Refining\n\nBody"
        )
        let draftingID = try writeNote(
            libraryURL: setup.libraryURL,
            collection: "Inbox",
            title: "Drafting Note",
            markdown: "# Drafting\n\nBody"
        )
        await setup.manager.rebuildLibraryIndex(libraryURL: setup.libraryURL)

        setup.manager.setNoteState(noteID: refiningID, state: .refining)
        setup.selection.selectCollection("Inbox")
        setup.selection.selectNote(refiningID)

        await togglePreviewModeCommand.perform(setup.context)
        XCTAssertTrue(setup.uiState.isPreviewModeEnabled)
        XCTAssertTrue(setup.notePreviewSessionState.hasPreviewedInSession(noteID: refiningID))

        setup.selection.selectNote(draftingID)
        await togglePreviewModeCommand.perform(setup.context)
        XCTAssertFalse(setup.notePreviewSessionState.hasPreviewedInSession(noteID: draftingID))
    }

    // MARK: - Helpers

    private struct Setup {
        let context: CommandContext
        let manager: LibraryManager
        let selection: SelectionModel
        let uiState: UIState
        let notePreviewSessionState: NotePreviewSessionController
        let libraryURL: URL
    }

    private func makeContext() async throws -> Setup {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let manager = LibraryManager()
        let selection = SelectionModel()
        let uiState = UIState()
        let notePreviewSessionState = NotePreviewSessionController()

        manager.bind(selection: selection)
        await manager.setActiveLibrary(libraryURL)
        await manager.rebuildLibraryIndex(libraryURL: libraryURL)

        return Setup(
            context: CommandContext(
                libraryManager: manager,
                selection: selection,
                uiState: uiState,
                notePreviewSessionState: notePreviewSessionState
            ),
            manager: manager,
            selection: selection,
            uiState: uiState,
            notePreviewSessionState: notePreviewSessionState,
            libraryURL: libraryURL
        )
    }

    @discardableResult
    private func writeNote(
        libraryURL: URL,
        collection: String,
        title: String,
        markdown: String
    ) throws -> String {
        let created = try NoteStore.create(
            libraryURL: libraryURL,
            collection: collection,
            title: title
        )
        _ = try NoteStore.save(
            libraryURL: libraryURL,
            noteID: created.summary.id,
            content: markdown
        )
        return created.summary.id
    }

    private func readPersistedIndex(libraryURL: URL) throws -> LibraryIndex {
        let persistedURL = libraryURL
            .appendingPathComponent(".softdraft", isDirectory: true)
            .appendingPathComponent("library.json")
        let data = try Data(contentsOf: persistedURL)
        return try JSONDecoder().decode(LibraryIndex.self, from: data)
    }
}
