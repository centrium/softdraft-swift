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
    shortcut: KeyboardShortcut("m", modifiers: [.command, .shift]),
    isEnabled: { ctx, arguments in
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil
    },
    perform: { ctx, arguments in
        guard let noteID = arguments.noteID ?? ctx.selection.selectedNoteID else { return }
        ctx.selection.selectNote(noteID)

        // Phase 1: intent only.
        // This command deliberately does NOT complete the action.
        ctx.selection.pendingMove = PendingMove(
            noteID: noteID,
            destinationCollection: nil
        )
    }
)
