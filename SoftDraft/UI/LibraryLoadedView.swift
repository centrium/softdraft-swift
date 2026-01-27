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
    @State private var isResolvingInitialNote = false

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
                onNotesLoaded: { _ in
                    // Selection handled centrally
                }
            )

        } detail: {

            // ───────── Editor surface ─────────
            NoteSurfaceView(
                noteID: selection.selectedNoteID
            )
        }
        .task(id: selectedCollection) {
            resolveInitialNoteIfNeeded()
        }
        .onChange(of: selection.selectedNoteID) { _, newValue in
            guard newValue == nil else { return }
            resolveInitialNoteIfNeeded()
        }
        .onChange(of: selectedCollection) { oldValue, newValue in
            guard oldValue != newValue else { return }

            // Reset note selection
            selection.selectedNoteID = nil

            Task {
                await LibraryMetaStore.updateLastActiveCollection(
                    libraryURL,
                    collectionId: newValue
                )
            }
        }
    }

    // MARK: - Initial note resolution

    private func resolveInitialNoteIfNeeded() {
        guard !isResolvingInitialNote else { return }
        guard selection.selectedNoteID == nil else { return }

        isResolvingInitialNote = true

        let targetCollection = selectedCollection
        let targetLibraryURL = libraryURL

        Task.detached(priority: .userInitiated) {
            let firstNoteID = loadFirstNoteID(
                libraryURL: targetLibraryURL,
                collection: targetCollection
            )

            await MainActor.run {
                guard selectedCollection == targetCollection else {
                    isResolvingInitialNote = false
                    resolveInitialNoteIfNeeded()
                    return
                }

                defer { isResolvingInitialNote = false }
                guard selection.selectedNoteID == nil else { return }
                selection.selectedNoteID = firstNoteID
            }
        }
    }

    private func loadFirstNoteID(
        libraryURL: URL,
        collection: String
    ) -> String? {

        let collectionURL = libraryURL
            .appendingPathComponent("collections")
            .appendingPathComponent(collection)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: collectionURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var bestNote: (id: String, modifiedAt: Date)?

        for url in files where url.pathExtension.lowercased() == "md" {
            guard
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true
            else { continue }

            let modified = values.contentModificationDate ?? .distantPast
            let candidate = "\(collection)/\(url.lastPathComponent)"

            if let current = bestNote {
                if modified > current.modifiedAt {
                    bestNote = (candidate, modified)
                }
            } else {
                bestNote = (candidate, modified)
            }
        }

        return bestNote?.id
    }
}
