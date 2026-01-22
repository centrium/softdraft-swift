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
    @StateObject private var notesModel: NotesListModel
    @StateObject private var commandRegistry: CommandRegistry

    init() {
        let libraryManager = LibraryManager()
        let selection = SelectionModel()
        let notesModel = NotesListModel()

        _libraryManager = StateObject(wrappedValue: libraryManager)
        _selection = StateObject(wrappedValue: selection)
        _notesModel = StateObject(wrappedValue: notesModel)

        _commandRegistry = StateObject(
            wrappedValue: CommandRegistry(
                context: CommandContext(
                    libraryManager: libraryManager,
                    selection: selection,
                    notes: notesModel
                )
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryManager)
                .environmentObject(selection)
                .environmentObject(notesModel)
                .environmentObject(commandRegistry)
                .task {
                    await libraryManager.resolveInitialLibrary()
                }
        }
        .commands {
            LibraryCommands(libraryManager: libraryManager)
                // 🔑 THIS LINE
        }.environmentObject(commandRegistry)   
    }
}
