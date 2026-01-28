//
//  NoteEditorView.swift
//  SoftDraft
//
//  Created by Matt Adams on 24/01/2026.
//

import SwiftUI
import MarkdownEditor

struct NoteEditorView: View {

    @EnvironmentObject private var libraryManager: LibraryManager

    @State var noteID: String
    var onReady: ((String) -> Void)? = nil

    private var isPrewarmInstance: Bool {
        noteID == "__prewarm__"
    }

    @State private var text: String = ""
    @State private var autosave = AutosaveController()
    @State private var isLoading = false
    @State private var hasPendingEdits = false
    @State private var observedExternalToken: UUID?

    var body: some View {
        MarkdownEditorView(
            text: $text,
            configuration: EditorConfiguration(
                fontFamily: "SoftdraftEditorMono",
                showLineNumbers: false
            )
        )
        .onChange(of: text) { _, newValue in
            guard !isLoading else { return }

            hasPendingEdits = true
            autosave.schedule {
                await save(content: newValue)
            }
        }
        .task(id: noteID) {
            await loadNote()
        }
        .onReceive(libraryManager.$externalChangeTokens) { tokens in
            guard
                let token = tokens[noteID],
                token != observedExternalToken,
                !hasPendingEdits
            else { return }

            observedExternalToken = token
            Task {
                await loadNote()
            }
        }

    }

    // MARK: - Load

    private func loadNote() async {
        autosave.cancel()

        await MainActor.run {
            isLoading = true
        }

        let loaded = await fetchContent()

        guard !Task.isCancelled else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        await applyLoadedText(loaded)
        await MainActor.run {
            observedExternalToken = libraryManager.externalChangeTokens[noteID]
            hasPendingEdits = false
        }

        if !isPrewarmInstance {
            await NotePrefetchCache.shared.put(
                noteID: noteID,
                content: loaded
            )
        }
    }

    // MARK: - Persistence

    private func load() async -> String {
        guard let libraryURL = libraryManager.activeLibraryURL else { return "" }

        return (try? NoteStore.load(
            libraryURL: libraryURL,
            noteID: noteID
        )) ?? ""
    }

    private func save(content: String) async {
        guard let libraryURL = libraryManager.activeLibraryURL else { return }

        let originalNoteID = noteID

        libraryManager.beginInternalWrite(noteID: originalNoteID)

        do {
            // 1️⃣ Save content (content-only operation)
            _ = try NoteStore.save(
                libraryURL: libraryURL,
                noteID: originalNoteID,
                content: content
            )

            // 2️⃣ Decide + perform rename if needed
            if let newNoteID = try RenameNote(
                libraryURL: libraryURL,
                noteID: originalNoteID,
                content: content
            ) {
                // 3️⃣ Update editor state immediately (DO NOT wait for watcher)
                await MainActor.run {
                    self.noteID = newNoteID
                    libraryManager.replaceNoteID(
                        oldID: originalNoteID,
                        newID: newNoteID
                    )
                }
            }

        } catch {
            libraryManager.endInternalWrite(noteID: originalNoteID)
            return
        }

        libraryManager.endInternalWrite(noteID: noteID)

        await MainActor.run {
            if text == content {
                hasPendingEdits = false
            }
        }

        if !isPrewarmInstance {
            await NotePrefetchCache.shared.put(
                noteID: noteID,
                content: content
            )
        }
    }
    private func fetchContent() async -> String {
        if let prefetched = await NotePrefetchCache.shared.consume(noteID: noteID) {
            return prefetched
        }

        guard let libraryURL = libraryManager.activeLibraryURL else {
            return ""
        }

        await NotePrefetchCache.shared.preload(
            libraryURL: libraryURL,
            noteID: noteID
        )

        if let awaited = await NotePrefetchCache.shared.consume(noteID: noteID) {
            return awaited
        }

        return await load()
    }

    @MainActor
    private func applyLoadedText(_ value: String) {
        // ✅ Do NOT clear text first
        // Replace content only when ready
        text = value
        isLoading = false
        onReady?(noteID)
    }
}
