//
//  PersistentEditorHost.swift
//  SoftDraft
//
//  Created by Matt Adams on 27/01/2026.
//

import SwiftUI
import MarkdownEditor

struct PersistentEditorHost: View {
    @EnvironmentObject private var libraryManager: LibraryManager

    // Incoming identity (selection-driven)
    let noteID: String?

    // Editor-owned mutable identity (CRITICAL for rename)
    @State private var currentNoteID: String?

    @State private var text: String = ""
    @State private var autosave = AutosaveController()
    @State private var isLoading = false
    @State private var isApplyingLoadedText = false
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

        // ───────── Text change → autosave ─────────
        .onChange(of: text) { _, newValue in
            guard
                !isLoading,
                !isApplyingLoadedText,
                let id = currentNoteID
            else { return }

            libraryManager.currentNoteText = newValue
            hasPendingEdits = true

            autosave.schedule {
                await save(noteID: id, content: newValue)
            }
        }

        // ───────── Selection change → load note ─────────
        .task(id: noteID) {
            guard noteID != currentNoteID else { return }

            currentNoteID = noteID

            guard let id = noteID else {
                autosave.cancel()
                text = ""
                libraryManager.currentNoteText = ""
                isLoading = false
                isApplyingLoadedText = false
                hasPendingEdits = false
                observedExternalToken = nil
                return
            }

            await loadIntoEditor(noteID: id)
        }

        // ───────── External change reconciliation ─────────
        .onReceive(libraryManager.$externalChangeTokens) { tokens in
            guard
                let id = currentNoteID,
                let token = tokens[id],
                token != observedExternalToken,
                !hasPendingEdits
            else { return }

            observedExternalToken = token

            Task {
                await loadIntoEditor(noteID: id)
            }
        }
    }

    // MARK: - Load

    private func loadIntoEditor(noteID: String) async {
        autosave.cancel()

        await MainActor.run {
            isLoading = true
            isApplyingLoadedText = true
        }

        guard let libraryURL = libraryManager.activeLibraryURL else {
            await MainActor.run {
                text = ""
                libraryManager.currentNoteText = ""
                hasPendingEdits = false
                observedExternalToken = nil
            }
            await finishApplyingLoadedText()
            return
        }

        let loaded =
            (try? NoteStore.load(
                libraryURL: libraryURL,
                noteID: noteID
            )) ?? ""

        guard !Task.isCancelled else {
            await finishApplyingLoadedText()
            return
        }

        await MainActor.run {
            text = loaded
            libraryManager.currentNoteText = loaded
            hasPendingEdits = false
            observedExternalToken = libraryManager.externalChangeTokens[noteID]
        }

        await finishApplyingLoadedText()
    }

    @MainActor
    private func finishApplyingLoadedText() async {
        isLoading = false

        // Delay clearing the guard flag until the next run loop tick so the
        // pending onChange triggered by text assignment does not schedule saves.
        Task { @MainActor in
            isApplyingLoadedText = false
        }
    }

    // MARK: - Save + Rename

    private func save(noteID: String, content: String) async {
        guard let libraryURL = libraryManager.activeLibraryURL else { return }

        var didRename = false

        libraryManager.beginInternalWrite(noteID: noteID)

        do {
            // 1️⃣ Save content
            _ = try NoteStore.save(
                libraryURL: libraryURL,
                noteID: noteID,
                content: content
            )

            await libraryManager.reconcileSavedNoteImmediately(
                noteID: noteID,
                libraryURL: libraryURL
            )

            // 2️⃣ Attempt rename (your existing helper)
            if let newID = try RenameNote(
                libraryURL: libraryURL,
                noteID: noteID,
                content: content
            ) {
                didRename = true

                await MainActor.run {
                    // 🔑 Editor continuity
                    currentNoteID = newID

                    // 🔑 Sidebar + selection continuity
                    libraryManager.replaceNoteID(
                        oldID: noteID,
                        newID: newID
                    )

                    observedExternalToken =
                        libraryManager.externalChangeTokens[newID]
                }
            }

        } catch {
            libraryManager.endInternalWrite(noteID: noteID)
            return
        }

        libraryManager.endInternalWrite(
            noteID: currentNoteID ?? noteID
        )

        if !didRename {
            await MainActor.run {
                libraryManager.refreshNoteID(noteID)
            }
        }

        await MainActor.run {
            if text == content {
                hasPendingEdits = false
            }
        }
    }
}
