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
                    guard selection.selectedNoteID == nil else { return }
                    Task { @MainActor in
                        selection.selectedNoteID = notes.first?.id
                    }
                }
            )

        } detail: {

            // ───────── Read-only note viewer ─────────
            NoteDetailView(
                libraryURL: libraryURL,
                noteID: selection.selectedNoteID
            )
        }
        .onChange(of: selectedCollection) { oldValue, newValue in
            guard oldValue != newValue else { return }

            // Reset note selection deterministically
            Task { @MainActor in
                selection.selectedNoteID = nil
            }

            Task {
                await LibraryMetaStore.updateLastActiveCollection(
                    libraryURL,
                    collectionId: newValue
                )
            }
        }
    }
}
