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

    @StateObject private var model = NotesListModel()
    @State private var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(model.notes, id: \.id) { note in
                NoteRow(note: note)
                    .tag(note.id)
            }
        }
        .listStyle(.inset)
        .navigationTitle(collection)
        .onChange(of: collection) { _, newCollection in
            Task {
                await model.load(
                    libraryURL: libraryURL,
                    collection: newCollection
                )
            }
        }
    }
}
