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

        let currentCollection = (pending.noteID as NSString).deletingLastPathComponent

        let selectionPlan: (preferredNextID: String?, affectedVisibleList: Bool)
        if currentCollection != destination {
            selectionPlan = await ctx.libraryManager.prepareSelectionForRemoval(of: pending.noteID)
        } else {
            selectionPlan = (nil, false)
        }

        // Clear pending state FIRST
        ctx.selection.pendingMove = nil

        print("➡️ Moving \(pending.noteID) to \(destination)")

        await ctx.libraryManager.beginInternalWrite(noteID: pending.noteID)
        do {
            let result = try NoteStore.move(
                libraryURL: libraryURL,
                noteID: pending.noteID,
                destCollection: destination
            )
            print("✅ Move result:", result)
            ctx.libraryManager.suppressEvents(for: result)
        } catch {
            print("❌ Failed to move note:", error)
            await ctx.libraryManager.endInternalWrite(noteID: pending.noteID)
            return
        }

        await ctx.libraryManager.endInternalWrite(noteID: pending.noteID)

        ctx.libraryManager.reloadCurrentCollection(
            preferredSelection: selectionPlan.preferredNextID,
            enforceSelection: selectionPlan.affectedVisibleList
        )
    }
)
