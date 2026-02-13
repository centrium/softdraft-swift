//
//  ConfirmMoveNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
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
        guard
            let pending = ctx.selection.pendingMove,
            let destination = pending.destinationCollection,
            let libraryURL = ctx.libraryManager.activeLibraryURL
        else {
            return
        }

        let currentCollection = (pending.noteID as NSString).deletingLastPathComponent

        let selectionPlan: (preferredNextID: String?, affectedVisibleList: Bool)
        if currentCollection != destination {
            selectionPlan = ctx.libraryManager.prepareSelectionForRemoval(of: pending.noteID)
        } else {
            selectionPlan = (nil, false)
        }

        // Clear pending state FIRST
        ctx.selection.pendingMove = nil

        ctx.libraryManager.beginInternalWrite(noteID: pending.noteID)
        do {
            let result = try NoteStore.move(
                libraryURL: libraryURL,
                noteID: pending.noteID,
                destCollection: destination
            )
            ctx.libraryManager.replaceNoteID(
                oldID: pending.noteID,
                newID: result
            )
            ctx.libraryManager.suppressEvents(for: result)
        } catch {
            ctx.libraryManager.endInternalWrite(noteID: pending.noteID)
            ctx.uiState.requestNotesListFocus()
            return
        }

        ctx.libraryManager.endInternalWrite(noteID: pending.noteID)

        ctx.libraryManager.reloadCurrentCollection(
            preferredSelection: selectionPlan.preferredNextID,
            enforceSelection: selectionPlan.affectedVisibleList
        )
        ctx.uiState.requestNotesListFocus()
    }
)
