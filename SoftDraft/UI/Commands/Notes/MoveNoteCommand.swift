//
//  MoveNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import SwiftUI

func makeMoveNoteCommand(
    destinationCollection: String
) -> AppCommand {

    AppCommand(
        id: "note.move",
        title: "Move Note",
        shortcut: KeyboardShortcut("m", modifiers: [.command]),
        isEnabled: { ctx in
            ctx.selection.selectedNoteID != nil
        },
        perform: { ctx in
            guard let noteID = ctx.selection.selectedNoteID else { return }

            // Begin two-step move
            ctx.selection.pendingMove = PendingMove(noteID: noteID)
        }
    )
}

