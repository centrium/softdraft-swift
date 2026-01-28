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
    @StateObject private var commandRegistry: CommandRegistry

    init() {
        let libraryManager = LibraryManager()
        let selection = SelectionModel()
        libraryManager.bind(selection: selection)

        _libraryManager = StateObject(wrappedValue: libraryManager)
        _selection = StateObject(wrappedValue: selection)

        _commandRegistry = StateObject(
            wrappedValue: CommandRegistry(
                context: CommandContext(
                    libraryManager: libraryManager,
                    selection: selection
                )
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryManager)
                .environmentObject(selection)
                .environmentObject(commandRegistry)
                .task {
                    await libraryManager.resolveInitialLibrary()
                }
        }
        .commands {
            GlobalCommands(commandRegistry: commandRegistry)
            LibraryCommands(libraryManager: libraryManager)
            
        }.environmentObject(commandRegistry)
    }
}
