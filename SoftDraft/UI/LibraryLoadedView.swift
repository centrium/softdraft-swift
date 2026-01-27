//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

struct LibraryLoadedView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager

    @State private var selectedCollection: String
    @State private var editorPrewarmed = false

    init(libraryURL: URL) {
        self.libraryURL = libraryURL

        let meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()
        let initialCollection =
            meta.lastActiveCollectionId?
                .trimmingCharacters(in: .whitespacesAndNewlines)

        _selectedCollection = State(
            initialValue: (initialCollection?.isEmpty == false)
                ? initialCollection!
                : "Inbox"
        )
    }

    var body: some View {
        NavigationSplitView {

            // ───────── Sidebar ─────────
            CollectionsSidebar(
                libraryURL: libraryURL,
                selectedCollection: $selectedCollection
            )
            .navigationSplitViewColumnWidth(
                min: 240,
                ideal: 280,
                max: 340
            )

        } content: {

            // ───────── Notes list ─────────
            NotesListView(
                libraryURL: libraryURL,
                collection: selectedCollection,
                onNotesLoaded: { notes in
                    // Select first note immediately if none selected
                    if selection.selectedNoteID == nil {
                        selection.selectedNoteID = notes.first?.id
                    }
                }
            )

        } detail: {

            ZStack {
                // ───────── Main editor surface ─────────
                NoteSurfaceView(
                    noteID: selection.selectedNoteID,
                    libraryURL: libraryURL
                )

                // ───────── Hidden prewarm editor ─────────
                if !editorPrewarmed {
                    NoteEditorView(noteID: "__prewarm__") { _ in
                        editorPrewarmed = true
                    }
                    .opacity(0)
                    .frame(width: 0, height: 0)
                }
            }
        }
        .onChange(of: selectedCollection) { oldValue, newValue in
            guard oldValue != newValue else { return }

            // Reset selection on collection change
            selection.selectedNoteID = nil

            Task {
                await LibraryMetaStore.updateLastActiveCollection(
                    libraryURL,
                    collectionId: newValue
                )
            }
        }
    }
}
