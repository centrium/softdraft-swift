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
            Button("New Note") {
                commandRegistry.run("note.create")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.create"))
            Button("New Collection") {
                commandRegistry.run("collection.create")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("collection.create"))
            
            Button("Open Library…") {
                openLibrary()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        
        // --------- Collection commands --------
        CommandMenu("Collections") {

            Button("Rename Current Collection") {
                commandRegistry.run("collection.rename.begin")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("collection.rename.begin"))
            
        }

        // ───────── Note commands ─────────
        CommandMenu("Note") {

            Button("Toggle Pin") {
                commandRegistry.run("note.togglePin")
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.togglePin"))
            Button("Move Note") {
                commandRegistry.run("note.move")
            }
            .keyboardShortcut("m", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.move"))
            Button("Delete Note") {
                commandRegistry.run("note.delete")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.delete"))
        }
    }

    private func openLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await libraryManager.setActiveLibrary(url)
            }
        }
    }
}
