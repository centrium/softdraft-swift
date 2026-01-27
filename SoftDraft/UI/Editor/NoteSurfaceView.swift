//
//  NoteSurfaceView.swift
//  SoftDraft
//

import SwiftUI

struct NoteSurfaceView: View {

    let noteID: String?
    let libraryURL: URL

    @State private var showLoadingAffordance = false
    @State private var activeNoteID: String?
    @State private var shellDebounceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)

            if let noteID {
                NoteEditorView(noteID: noteID) { readyNoteID in
                    handleEditorReady(readyNoteID)
                }
            } else {
                EditorPlaceholderView()
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

    private func prepareShell(for noteID: String?) {
        activeNoteID = noteID

        shellDebounceTask?.cancel()

        guard let noteID else {
            showLoadingAffordance = false
            return
        }

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

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
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

struct EditorPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)

            Text("Select a note to start writing")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}
