//
//  FocusEditorCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let focusEditorCommand = AppCommand(
    id: "focus.editor",
    title: "Focus Editor",
    shortcut: KeyboardShortcut("e", modifiers: [.command, .option]),
    isEnabled: { ctx in
        ctx.libraryManager.activeLibraryURL != nil &&
        ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        guard ctx.selection.selectedNoteID != nil else { return }
        ctx.uiState.isPreviewModeEnabled = false
        ctx.uiState.requestFocus(.editor)
    }
)
