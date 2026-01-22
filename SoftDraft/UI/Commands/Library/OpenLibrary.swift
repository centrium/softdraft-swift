//
//  Commands.swift
//  SoftDraft
//

import SwiftUI

struct LibraryCommands: Commands {

    @ObservedObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry

    init(libraryManager: LibraryManager) {
        self.libraryManager = libraryManager
    }

    var body: some Commands {

        // ───────── File / Library ─────────
        CommandGroup(replacing: .newItem) {
            Button("Open Library…") {
                openLibrary()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        // ───────── Note commands ─────────
        CommandMenu("Note") {

            Button("Toggle Pin") {
                commandRegistry.run("note.togglePin")
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.togglePin"))
        }
    }

    private func openLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                try? await libraryManager.setActiveLibrary(url)
            }
        }
    }
}
