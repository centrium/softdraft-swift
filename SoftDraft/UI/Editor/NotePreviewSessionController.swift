//
//  NotePreviewSessionController.swift
//  SoftDraft
//

import Foundation
import Combine

@MainActor
final class NotePreviewSessionController: ObservableObject {

    private var previewedRefiningNotes: Set<String> = []

    func markPreviewShown(noteID: String, state: NoteState) {
        guard state == .refining else { return }
        previewedRefiningNotes.insert(noteID)
    }

    func hasPreviewedInSession(noteID: String) -> Bool {
        previewedRefiningNotes.contains(noteID)
    }
}
