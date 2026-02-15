//
//  TogglePreviewModeCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 01/02/2026.
//

import SwiftUI

let togglePreviewModeCommand = AppCommand(
    id: "view.togglePreviewMode",
    title: "Preview Note",
    shortcut: KeyboardShortcut("p", modifiers: [.command, .option]),
    isEnabled: { ctx in
        ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        guard let noteID = ctx.selection.selectedNoteID else { return }
        let noteState = ctx.libraryManager.noteState(noteID: noteID)

        let isEnteringPreview = !ctx.uiState.isPreviewModeEnabled
        if isEnteringPreview {
            ctx.notePreviewSessionState.markPreviewShown(
                noteID: noteID,
                state: noteState
            )
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            ctx.uiState.setSurface(isEnteringPreview ? .preview : .editor)
        }
    }
)
