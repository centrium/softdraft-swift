//
//  NoteDetailView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct NoteDetailView: View {

    let libraryURL: URL
    let noteID: String?

    @StateObject private var model = NoteViewerModel()

    var body: some View {
        Group {
            if let noteID {

                contentView
                    .task(id: noteID) {
                        await model.load(
                            libraryURL: libraryURL,
                            noteID: noteID
                        )
                    }

            } else {
                emptyState
                    .onAppear {
                        model.clear()
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - States

    private var contentView: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Text(model.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
                .overlay(alignment: .topTrailing) {
                    if model.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(8)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("Select a note")
            .foregroundStyle(.secondary)
    }
}
