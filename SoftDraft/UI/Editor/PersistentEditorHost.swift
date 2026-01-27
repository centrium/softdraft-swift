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
      autosave.schedule { await save(noteID: noteID, content: newValue) }
    }
    .task(id: noteID) {
      guard let noteID else { return }
      await loadIntoEditor(noteID: noteID)
    }
  }

  private func loadIntoEditor(noteID: String) async {
    autosave.cancel()
    isLoading = true
    let loaded = (try? NoteStore.load(libraryURL: libraryManager.activeLibraryURL!, noteID: noteID)) ?? ""
    if !Task.isCancelled { text = loaded }
    isLoading = false
  }

  private func save(noteID: String, content: String) async {
    guard let libraryURL = libraryManager.activeLibraryURL else { return }
    try? NoteStore.save(libraryURL: libraryURL, noteID: noteID, content: content)
  }
}
