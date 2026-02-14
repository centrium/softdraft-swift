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
    isEnabled: { ctx, arguments in
        let noteID = arguments.noteID ?? ctx.selection.pendingMove?.noteID
        let destination = arguments.collectionID ?? ctx.selection.pendingMove?.destinationCollection
        return
            noteID != nil &&
            destination != nil &&
            ctx.libraryManager.activeLibraryURL != nil
    },
    perform: { ctx, arguments in
        let noteID = arguments.noteID ?? ctx.selection.pendingMove?.noteID
        let destination = arguments.collectionID ?? ctx.selection.pendingMove?.destinationCollection

        guard
            let noteID,
            let destination,
            let libraryURL = ctx.libraryManager.activeLibraryURL
        else {
            return
        }

        let currentCollection = (noteID as NSString).deletingLastPathComponent

        let selectionPlan: (preferredNextID: String?, affectedVisibleList: Bool)
        if currentCollection != destination {
            selectionPlan = ctx.libraryManager.prepareSelectionForRemoval(of: noteID)
        } else {
            selectionPlan = (nil, false)
        }

        // Clear pending state FIRST
        ctx.selection.pendingMove = nil

        ctx.libraryManager.beginInternalWrite(noteID: noteID)
        do {
            let result = try NoteStore.move(
                libraryURL: libraryURL,
                noteID: noteID,
                destCollection: destination
            )
            ctx.libraryManager.replaceNoteID(
                oldID: noteID,
                newID: result
            )
            ctx.libraryManager.suppressEvents(for: result)
        } catch {
            ctx.libraryManager.endInternalWrite(noteID: noteID)
            ctx.uiState.requestNotesListFocus()
            return
        }

        ctx.libraryManager.endInternalWrite(noteID: noteID)

        ctx.libraryManager.reloadCurrentCollection(
            preferredSelection: selectionPlan.preferredNextID,
            enforceSelection: selectionPlan.affectedVisibleList
        )
        ctx.uiState.requestNotesListFocus()
    }
)
