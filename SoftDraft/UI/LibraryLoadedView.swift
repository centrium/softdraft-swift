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
    @State private var collectionSummaries: [String: CollectionLandingSummary] = [:]

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

    private var landingSummary: CollectionLandingSummary? {
        collectionSummaries[selectedCollection]
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
                collection: selectedCollection
            )

        } detail: {

            ZStack {
               // 1) Always-mounted editor (single instance for app session)
               PersistentEditorHost(noteID: selection.selectedNoteID)
                 .opacity(selection.selectedNoteID == nil ? 0 : 1)

               // 2) Landing view overlays while no note is selected
               if selection.selectedNoteID == nil {
                 CollectionLandingView(
                   collectionName: selectedCollection,
                   summary: landingSummary
                 )
                 .opacity(selection.selectedNoteID == nil ? 1 : 0)
                 .allowsHitTesting(selection.selectedNoteID == nil)
                 .animation(.easeOut(duration: 0.14), value: selection.selectedNoteID)
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
        .onReceive(libraryManager.$visibleNotes) { notes in
            guard let activeCollection = libraryManager.visibleCollectionID else { return }
            collectionSummaries[activeCollection] = makeSummary(
                for: activeCollection,
                notes: notes
            )
        }
    }

    private func makeSummary(
        for collectionID: String,
        notes: [NoteSummary]
    ) -> CollectionLandingSummary {
        let latestDate = notes.map(\.modifiedAt).max()
        return CollectionLandingSummary(
            noteCount: notes.count,
            lastUpdated: latestDate
        )
    }
}
