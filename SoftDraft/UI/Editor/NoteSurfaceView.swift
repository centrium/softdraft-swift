//
//  NoteSurfaceView.swift
//  SoftDraft
//

import SwiftUI

struct NoteSurfaceView: View {

    let noteID: String
    let libraryURL: URL

    @Environment(\.colorScheme) private var colorScheme
    @State private var showLoadingAffordance = false
    @State private var activeNoteID: String?
    @State private var shellDebounceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            editorBackground

            NoteEditorView(noteID: noteID) { readyNoteID in
                handleEditorReady(readyNoteID)
            }

            if showLoadingAffordance {
                EditorShellView(showSpinner: true)
                    .transition(.opacity)
            }
        }
        .onAppear {
            prepareShell(for: noteID)
        }
        .onChange(of: noteID) { _, newValue in
            prepareShell(for: newValue)
        }
    }

    private var editorBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.11, green: 0.11, blue: 0.10)
        }
        return Color(red: 0.97, green: 0.96, blue: 0.94)
    }

    private func prepareShell(for noteID: String) {
        activeNoteID = noteID

        shellDebounceTask?.cancel()

        Task {
            await NotePrefetchCache.shared.preload(
                libraryURL: libraryURL,
                noteID: noteID
            )
        }

        shellDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard activeNoteID == noteID else { return }

                withAnimation(.easeIn(duration: 0.15)) {
                    showLoadingAffordance = true
                }
            }
        }
    }

    private func handleEditorReady(_ noteID: String) {
        guard activeNoteID == noteID else { return }

        shellDebounceTask?.cancel()
        shellDebounceTask = nil

        withAnimation(.easeOut(duration: 0.2)) {
            showLoadingAffordance = false
        }
    }
}

struct EditorShellView: View {
    let showSpinner: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark
             ? Color(red: 0.11, green: 0.11, blue: 0.10)
             : Color(red: 0.97, green: 0.96, blue: 0.94))
                .opacity(0.9)

            if showSpinner {
                ProgressView()
                    .controlSize(.small)
                    .opacity(0.35)
            }
        }
        .allowsHitTesting(false)
    }
}
