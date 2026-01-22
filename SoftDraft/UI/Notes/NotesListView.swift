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

    var body: some View {
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
