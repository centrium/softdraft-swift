//
//  MoveNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import SwiftUI

let moveNoteCommand = AppCommand(
    id: "note.move",
    title: "Move Note",
    shortcut: KeyboardShortcut("m", modifiers: [.command]),
    isEnabled: { ctx in
        ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        guard let noteID = ctx.selection.selectedNoteID else { return }

        // Phase 1: intent only.
        // This command deliberately does NOT complete the action.
        ctx.selection.pendingMove = PendingMove(
            noteID: noteID,
            destinationCollection: nil
        )
    }
)
