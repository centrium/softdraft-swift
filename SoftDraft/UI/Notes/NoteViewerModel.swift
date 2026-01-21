//
//  NoteViewerModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation
import Combine

@MainActor
final class NoteViewerModel: ObservableObject {

    @Published private(set) var content: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var lastNoteID: String?
    private var loadingTask: Task<Void, Never>?

    func load(
        libraryURL: URL,
        noteID: String
    ) async {
        guard noteID != lastNoteID else { return }
        lastNoteID = noteID

        errorMessage = nil
        loadingTask?.cancel()

        // ⚠️ DO NOT clear content here
        // Keep old content visible

        loadingTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if !Task.isCancelled {
                isLoading = true
            }
        }

        do {
            let text = try await Task {
                try NoteStore.load(
                    libraryURL: libraryURL,
                    noteID: noteID
                )
            }.value

            loadingTask?.cancel()
            isLoading = false

            // Swap content in one go
            content = text
        } catch {
            loadingTask?.cancel()
            isLoading = false
            errorMessage = "Failed to load note"
        }
    }

    func clear() {
        loadingTask?.cancel()
        isLoading = false
        content = ""
        errorMessage = nil
        lastNoteID = nil
    }
}
