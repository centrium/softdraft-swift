//
//  CommandContext.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation

// Commands/CommandContext.swift

struct CommandContext {

    let libraryManager: LibraryManager
    let selection: SelectionModel
    let uiState: UIState
    let notePreviewSessionState: NotePreviewSessionController
    var libraryURL: URL? {
        libraryManager.currentLibraryURL
    }

    func selectNoteResolvingInitialSurface(_ noteID: String) {
        selection.selectNote(noteID)
    }
}
