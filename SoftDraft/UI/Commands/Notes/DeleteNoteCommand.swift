//
//  DeleteNoteCommand.swift
//  SoftDraft
//

import SwiftUI

let deleteNoteCommand = AppCommand(
    id: "note.delete",
    title: "Delete Note",
    shortcut: KeyboardShortcut(.delete, modifiers: [.command]),
    isEnabled: { ctx, arguments in
        guard ctx.libraryURL != nil else { return false }
        return (arguments.noteID ?? ctx.selection.selectedNoteID) != nil
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let noteID = arguments.noteID ?? ctx.selection.selectedNoteID
        else { return }

        let collectionID = ctx.libraryManager.collectionID(for: noteID)
        await ctx.libraryManager.deleteNote(
            noteID,
            from: collectionID,
            libraryURL: libraryURL
        )
    }
)
