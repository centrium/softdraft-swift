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
    @EnvironmentObject private var model: NotesListModel
    @State private var listSelection: String?

    var onNotesLoaded: (([NoteSummary]) -> Void)?
    @EnvironmentObject private var libraryManager: LibraryManager
    
    private var collections: [String] {
        libraryManager.allCollections()
    }
    
    var body: some View {
        ZStack {

            // ─────────────────────────────
            // Main notes list
            // ─────────────────────────────
            List(selection: listSelectionBinding) {
                ForEach(model.notes, id: \.id) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                }
            }
            .navigationTitle(collection)
            .task {
                await model.load(
                    libraryURL: libraryURL,
                    collection: collection
                )
                onNotesLoaded?(model.notes)
            }
            .onChange(of: collection) { _, newCollection in
                Task {
                    await model.load(
                        libraryURL: libraryURL,
                        collection: newCollection
                    )
                    onNotesLoaded?(model.notes)
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

                        do {
                            _ = try NoteStore.move(
                                libraryURL: libraryURL,
                                noteID: pending.noteID,
                                destCollection: destination
                            )
                            model.reloadCurrentCollection()
                        } catch {
                            // TODO: Surface this error to the user if needed
                            print("Failed to move note \(pending.noteID) to collection \(destination): \(error)")
                        }
                    }
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
}

