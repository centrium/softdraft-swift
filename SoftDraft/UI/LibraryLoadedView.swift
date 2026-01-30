//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.

import SwiftUI

struct LibraryLoadedView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var uiState: UIState

    @State private var collectionSummaries: [String: CollectionLandingSummary] = [:]

    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private var landingSummary: CollectionLandingSummary? {
        collectionSummaries[selectedCollection]
    }

    var body: some View {
        ZStack {

            if uiState.isZenModeEnabled {
                zenEditor
                    .transition(
                        .opacity
                    )
            } else {
                normalLayout
                    .transition(
                        .opacity
                    )
            }

        }
        .animation(.easeInOut(duration: 0.22), value: uiState.isZenModeEnabled)
    }
}

private extension LibraryLoadedView {

    var zenEditor: some View {
        PersistentEditorHost(noteID: selection.selectedNoteID)
            .ignoresSafeArea()
    }
}

private extension LibraryLoadedView {

    var normalLayout: some View {
        NavigationSplitView {

            // ───────── Sidebar ─────────
            CollectionsSidebar(
                libraryURL: libraryURL
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

            editorStack
        }
        .onReceive(libraryManager.$visibleNotes) { notes in
            guard let activeCollection = libraryManager.visibleCollectionID else { return }
            collectionSummaries[activeCollection] = makeSummary(
                for: activeCollection,
                notes: notes
            )
        }
    }
}

private extension LibraryLoadedView {

    var editorStack: some View {
        ZStack {

            // Editor (always mounted in normal mode)
            PersistentEditorHost(noteID: selection.selectedNoteID)
                .opacity(selection.selectedNoteID == nil ? 0 : 1)

            // Landing view (never shown in Zen)
            if selection.selectedNoteID == nil {
                CollectionLandingView(
                    collectionName: selectedCollection,
                    summary: landingSummary
                )
                .allowsHitTesting(true)
                .animation(.easeOut(duration: 0.14), value: selection.selectedNoteID)
            }
        }
    }
}

private extension LibraryLoadedView {

    func makeSummary(
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
