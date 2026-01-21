//
//  NotesListModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation
import Combine

@MainActor
final class NotesListModel: ObservableObject {

    @Published private(set) var notes: [NoteSummary] = []
    @Published private(set) var isLoading = false

    private var lastCollection: String?

    func load(
        libraryURL: URL,
        collection: String
    ) async {

        guard collection != lastCollection else { return }
        lastCollection = collection

        isLoading = true

        do {
            // This automatically runs off the main thread
            let fetchedNotes = try await Task {
                try NoteStore.list(
                    libraryURL: libraryURL,
                    collection: collection
                )
            }.value

            notes = fetchedNotes
            isLoading = false
        } catch {
            notes = []
            isLoading = false
        }
    }
}
