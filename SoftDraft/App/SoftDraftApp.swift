//
//  SoftDraftApp.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

@main
struct SoftdraftApp: App {

    @StateObject private var libraryManager: LibraryManager
    @StateObject private var selection: SelectionModel
    @StateObject private var uiState: UIState
    @StateObject private var notePreviewSessionState: NotePreviewSessionController
    @StateObject private var commandRegistry: CommandRegistry
    @StateObject private var searchIndex: SearchIndex

    @MainActor
    init() {
        let libraryManager = LibraryManager()
        let selection = SelectionModel()
        let uiState = UIState()
        let notePreviewSessionState = NotePreviewSessionController()
        let searchIndex = SearchIndex()

        selection.configurePreviewModeResolver(
            resolve: { noteID in
                let noteState = libraryManager.noteState(noteID: noteID)
                let surface = uiState.resolveInitialSurface(
                    for: noteID,
                    state: noteState,
                    sessionState: notePreviewSessionState
                )
                return surface == .preview
            },
            applyPreview: { isPreview in
                uiState.isPreviewModeEnabled = isPreview
            },
            resolveText: { noteID in
                guard let libraryURL = libraryManager.currentLibraryURL else { return "" }
                return (try? NoteStore.load(
                    libraryURL: libraryURL,
                    noteID: noteID
                )) ?? ""
            },
            applyText: { text in
                libraryManager.currentNoteText = text
            }
        )

        libraryManager.bind(selection: selection)
        libraryManager.bind(searchIndex: searchIndex)
        libraryManager.resolveInitialLibrarySync()

        _libraryManager = StateObject(wrappedValue: libraryManager)
        _selection = StateObject(wrappedValue: selection)
        _uiState = StateObject(wrappedValue: uiState)
        _notePreviewSessionState = StateObject(wrappedValue: notePreviewSessionState)
        _searchIndex = StateObject(wrappedValue: searchIndex)

        _commandRegistry = StateObject(
            wrappedValue: CommandRegistry(
                context: CommandContext(
                    libraryManager: libraryManager,
                    selection: selection,
                    uiState: uiState,
                    notePreviewSessionState: notePreviewSessionState
                )
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryManager)
                .environmentObject(selection)
                .environmentObject(uiState)
                .environmentObject(notePreviewSessionState)
                .environmentObject(commandRegistry)
                .environmentObject(searchIndex)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            GlobalCommands(commandRegistry: commandRegistry)
            LibraryCommands(libraryManager: libraryManager)
        }
        .environmentObject(commandRegistry)
    }
}
