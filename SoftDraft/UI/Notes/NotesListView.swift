//
//  NotesListView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct NotesListView: View {

    let libraryURL: URL
    let collection: String

    @EnvironmentObject private var selection: SelectionModel
    @State private var listSelection: String?

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    
    private var collections: [String] {
        libraryManager.allCollections()
    }
    
    var body: some View {
        ZStack {

            // ─────────────────────────────
            // Main notes list
            // ─────────────────────────────
            List(selection: listSelectionBinding) {
                ForEach(libraryManager.visibleNotes, id: \.id) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                }
            }
            .navigationTitle(collection)
            .task {
                await libraryManager.loadNotes(
                    libraryURL: libraryURL,
                    collection: collection
                )
                prefetchInitialNotes()
            }
            .onChange(of: collection) { _, newCollection in
                Task {
                    await libraryManager.loadNotes(
                        libraryURL: libraryURL,
                        collection: newCollection
                    )
                    prefetchInitialNotes()
                }
            }
            .onAppear {
                syncSelectionFromModel()
            }
            .onChange(of: selection.selectedNoteID) { _, newValue in
                guard listSelection != newValue else { return }
                listSelection = newValue
            }
            .onChange(of: listSelection) { _, newValue in
                guard selection.selectedNoteID != newValue else { return }
                Task { @MainActor in
                    selection.selectedNoteID = newValue
                }
            }

            // ─────────────────────────────
            // Move Note Picker (overlay)
            // ─────────────────────────────
            if let pending = selection.pendingMove {
                MoveNotePicker(
                    selection: selection,
                    collections: collections,
                    onSelect: { destination in
                        selection.pendingMove = nil

                        selection.pendingMove = PendingMove(
                            noteID: pending.noteID,
                            destinationCollection: destination
                        )
                        commandRegistry.run("note.move.confirm")
                    },
                    onCancel: {
                        commandRegistry.run("command.cancel")
                    },
                )
                .background(
                    Color.black.opacity(0.05)
                        .ignoresSafeArea()
                )
            }
        }
    }

    private var listSelectionBinding: Binding<String?> {
        Binding(
            get: { listSelection },
            set: { newValue in
                guard listSelection != newValue else { return }
                listSelection = newValue
            }
        )
    }

    private func syncSelectionFromModel() {
        guard listSelection != selection.selectedNoteID else { return }
        listSelection = selection.selectedNoteID
    }

    private func prefetchInitialNotes() {
        guard let libraryURL = libraryManager.activeLibraryURL else { return }
        guard libraryManager.visibleCollectionID == collection else { return }

        let targets = libraryManager.visibleNotes
            .prefix(3)
            .map(\.id)

        guard !targets.isEmpty else { return }

        Task {
            for id in targets {
                await NotePrefetchCache.shared.preload(
                    libraryURL: libraryURL,
                    noteID: id
                )
            }
        }
    }
}
