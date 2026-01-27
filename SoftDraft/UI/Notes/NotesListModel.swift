//
//  NotesListModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation
import Combine

@MainActor
final class NotesListModel: ObservableObject, NotesReloader {

    @Published private(set) var notes: [NoteSummary] = []
    @Published private(set) var activeCollection: String?
    @Published private(set) var isLoading = false

    private var libraryURL: URL?
    private var currentCollection: String?

    func load(
        libraryURL: URL,
        collection: String
    ) async {

        // Capture previous collection BEFORE overwriting
        let previousCollection = currentCollection

        // Persist context
        self.libraryURL = libraryURL
        self.currentCollection = collection
        
        // Only skip if truly redundant
       /* guard previousCollection != collection || notes.isEmpty else {
            return
        }*/

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedNotes = try await Task {
                try NoteStore.list(
                    libraryURL: libraryURL,
                    collection: collection
                )
            }.value

            notes = fetchedNotes
        } catch {
            notes = []
        }
        activeCollection = collection
    }

    // MARK: - NotesReloader

    func reloadCurrentCollection() {
        guard
            let libraryURL,
            let currentCollection
        else { return }
        Task {
            await load(
                libraryURL: libraryURL,
                collection: currentCollection
            )
        }
    }
}
