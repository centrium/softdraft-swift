//
//  DeleteNoteCommand.swift
//  SoftDraft
//

import SwiftUI

let deleteNoteCommand = AppCommand(
    id: "note.delete",
    title: "Delete Note",
    shortcut: KeyboardShortcut(.delete, modifiers: [.command]),
    isEnabled: { ctx in
        ctx.libraryURL != nil &&
        ctx.selection.selectedNoteID != nil &&
        ctx.selection.selectedCollectionID != nil
    },
    perform: { ctx in
        guard
            let libraryURL = ctx.libraryURL,
            let noteID = ctx.selection.selectedNoteID,
            let collectionID = ctx.selection.selectedCollectionID
        else { return }

        await ctx.libraryManager.deleteNote(
            noteID,
            from: collectionID,
            libraryURL: libraryURL
        )
    }
)
