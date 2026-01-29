//
//  NewNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 29/01/2026.
//

import SwiftUI

let createNoteCommand = AppCommand(
    id: "note.create",
    title: "New Note",
    shortcut: KeyboardShortcut("n", modifiers: [.command]),
    isEnabled: { ctx in
        ctx.libraryURL != nil &&
        ctx.selection.selectedCollectionID != nil
    },
    perform: { ctx in
        guard
            let libraryURL = ctx.libraryURL,
            let collectionID = ctx.selection.selectedCollectionID
        else { return }

        // Let LibraryManager decide filename + initial content
        let noteID = await ctx.libraryManager.createNote(
            in: collectionID,
            libraryURL: libraryURL
        )

        // Explicitly select the new note
        if let noteID {
            ctx.selection.selectNote(noteID)
        }
    }
)
