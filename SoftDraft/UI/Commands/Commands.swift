//
//  Commands.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

struct LibraryCommands: Commands {

    @ObservedObject private var libraryManager: LibraryManager

    init(libraryManager: LibraryManager) {
        self.libraryManager = libraryManager
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Library…") {
                openLibrary()
            }
            .keyboardShortcut("o", modifiers: [.command])
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

