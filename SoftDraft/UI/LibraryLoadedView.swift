//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

struct LibraryLoadedView: View {

    let libraryURL: URL

    @State private var selectedCollection: String
    @State private var selectedNoteID: String?

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
                selectedNoteID: $selectedNoteID
            )

        } detail: {

            // ───────── Note detail ─────────
            NoteDetailView(
                libraryURL: libraryURL,
                noteID: selectedNoteID
            )
        }
        .onChange(of: selectedCollection) { oldValue, newValue in
            guard oldValue != newValue else { return }

            Task {
                await LibraryMetaStore.updateLastActiveCollection(
                    libraryURL,
                    collectionId: newValue
                )
            }
        }
    }
}
