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

  let noteID: String?

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
      guard !isLoading, let noteID else { return }
      hasPendingEdits = true
      autosave.schedule { await save(noteID: noteID, content: newValue) }
    }
    .task(id: noteID) {
      guard let noteID else { return }
      await loadIntoEditor(noteID: noteID)
    }
    .onReceive(libraryManager.$externalChangeTokens) { tokens in
      guard
        let noteID,
        let token = tokens[noteID],
        token != observedExternalToken,
        !hasPendingEdits
      else { return }

      observedExternalToken = token
      Task {
        await loadIntoEditor(noteID: noteID)
      }
    }
  }

  private func loadIntoEditor(noteID: String) async {
    autosave.cancel()
    isLoading = true
    let loaded = (try? NoteStore.load(libraryURL: libraryManager.activeLibraryURL!, noteID: noteID)) ?? ""
    if !Task.isCancelled { text = loaded }
    isLoading = false
    hasPendingEdits = false
    observedExternalToken = libraryManager.externalChangeTokens[noteID]
  }

  private func save(noteID: String, content: String) async {
    guard let libraryURL = libraryManager.activeLibraryURL else { return }
    await libraryManager.beginInternalWrite(noteID: noteID)
    do {
      _ = try NoteStore.save(
        libraryURL: libraryURL,
        noteID: noteID,
        content: content
      )
    } catch {
      await libraryManager.endInternalWrite(noteID: noteID)
      return
    }
    await libraryManager.endInternalWrite(noteID: noteID)
    await MainActor.run {
      if text == content {
        hasPendingEdits = false
      }
    }
  }
}
