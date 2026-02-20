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
                .font(AppTypography.secondaryHeading)
                .foregroundStyle(.primary.opacity(0.88))

            Text("Open or create a library to begin.")
                .font(AppTypography.secondaryBody)
                .foregroundStyle(.secondary)

            Button("Open Library") {
                openLibrary()
            }
            .font(AppTypography.secondaryBodyEmphasis)
            .keyboardShortcut("o", modifiers: [.command])

            if let error {
                Text(error)
                    .font(AppTypography.caption)
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
            let canonicalURL = url.standardizedFileURL
            guard LibraryValidator.isLibraryRoot(canonicalURL) else {
                error = "Selected folder is not a valid SoftDraft library."
                return
            }

            error = nil
            Task {
                await libraryManager.setActiveLibrary(canonicalURL)
            }
        }
    }
}
