//
//  ConfirmMoveNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
//

//
//  ConfirmMoveNoteCommand.swift
//  SoftDraft
//

import SwiftUI

let confirmMoveNoteCommand = AppCommand(
    id: "note.move.confirm",
    title: "Confirm Move Note",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.selection.pendingMove != nil &&
        ctx.libraryManager.activeLibraryURL != nil
    },
    perform: { ctx in
        print("🚚 ConfirmMoveNoteCommand running")

        guard
            let pending = ctx.selection.pendingMove,
            let destination = pending.destinationCollection,
            let libraryURL = ctx.libraryManager.activeLibraryURL
        else {
            print("❌ Guard failed", ctx.selection.pendingMove as Any)
            return
        }

        // Clear pending state FIRST
        ctx.selection.pendingMove = nil

        print("➡️ Moving \(pending.noteID) to \(destination)")

        do {
            let result = try NoteStore.move(
                libraryURL: libraryURL,
                noteID: pending.noteID,
                destCollection: destination
            )
            print("✅ Move result:", result)
        } catch {
            print("❌ Failed to move note:", error)
            return
        }

        ctx.notes.reloadCurrentCollection()
    }
)

