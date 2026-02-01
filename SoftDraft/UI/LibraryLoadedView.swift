//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI
import Combine

struct LibraryLoadedView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @EnvironmentObject private var uiState: UIState

    @State private var collectionSummaries: [String: CollectionLandingSummary] = [:]

    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private var landingSummary: CollectionLandingSummary? {
        collectionSummaries[selectedCollection]
    }

    // ─────────────────────────────
    // Sidebar toolbar
    // ─────────────────────────────
    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {

        // Toggle Collections / Tags
        ToolbarItem(placement: .primaryAction) {
            Button {
                uiState.sidebarMode =
                    uiState.sidebarMode == .collections ? .tags : .collections
            } label: {
                Image(systemName:
                    uiState.sidebarMode == .collections
                    ? "tag"
                    : "folder"
                )
                .offset(y: 1)
            }
            .help(
                uiState.sidebarMode == .collections
                ? "Show Tags"
                : "Show Collections"
            )
        }

        // New note
        ToolbarItem(placement: .primaryAction) {
            Button {
                commandRegistry.run("note.create")
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note")
        }
    }

    // ─────────────────────────────
    // Body
    // ─────────────────────────────
    var body: some View {
        ZStack {
            normalLayout
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.22), value: uiState.isZenModeEnabled)
    }
}

// MARK: - Layout

private extension LibraryLoadedView {

    var normalLayout: some View {
        NavigationSplitView(columnVisibility: $uiState.splitViewVisibility) {

            LibraryRailView(libraryURL: libraryURL)
                .navigationSplitViewColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 360
                )
                .toolbar {
                    sidebarToolbar
                }

        } detail: {

            // ⬇️ Editor + Preview layering happens here
            layeredEditor
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

// MARK: - Layered Editor / Preview

private extension LibraryLoadedView {

    var layeredEditor: some View {
        ZStack {

            // ───────── Editor (always mounted) ─────────
            editorStack
                .allowsHitTesting(!uiState.isPreviewModeEnabled)
                .opacity(uiState.isPreviewModeEnabled ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: uiState.isPreviewModeEnabled)

            // ───────── Preview overlay ─────────
            previewStack
                .opacity(
                    uiState.isPreviewModeEnabled && selection.selectedNoteID != nil
                    ? 1
                    : 0
                )
                .allowsHitTesting(uiState.isPreviewModeEnabled)
                .animation(
                    .easeInOut(duration: 0.25),
                    value: uiState.isPreviewModeEnabled
                )
        }
    }
}

// MARK: - Editor Stack

private extension LibraryLoadedView {

    var editorStack: some View {
        ZStack {

            // Editor content
            PersistentEditorHost(noteID: selection.selectedNoteID)
                .opacity(selection.selectedNoteID == nil ? 0 : 1)

            // Landing view (no note selected)
            if selection.selectedNoteID == nil {
                CollectionLandingView(
                    collectionName: selectedCollection,
                    summary: landingSummary
                )
                .allowsHitTesting(true)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview Stack (mock)

private extension LibraryLoadedView {
    
    var previewStack: some View {
        NotePreviewSurface(text: libraryManager.currentNoteText)
    }
}

// MARK: - Helpers

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
