//
//  EmptyLibraryView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

struct EmptyLibraryView: View {

    @EnvironmentObject private var libraryManager: LibraryManager
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Softdraft")
                .font(.largeTitle)

            Text("Open or create a library to begin.")
                .foregroundStyle(.secondary)

            Button("Open Library") {
                openLibrary()
            }
            .keyboardShortcut("o", modifiers: [.command])

            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private func openLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Open Softdraft Library"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await libraryManager.setActiveLibrary(url)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
