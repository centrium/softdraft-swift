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

    var onNotesLoaded: (([NoteSummary]) -> Void)?

    var body: some View {
        List(selection: $selection.selectedNoteID) {
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
    }
}
