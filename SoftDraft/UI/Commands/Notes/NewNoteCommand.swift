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
        ctx.libraryURL != nil
    },
    perform: { ctx in
        guard let libraryURL = ctx.libraryURL else { return }

        let collectionID =
            ctx.selection.selectedNoteID
                .flatMap { ctx.libraryManager.collectionID(for: $0) }
            ?? ctx.selection.selectedCollectionID
            ?? "Inbox"

        let noteID = await ctx.libraryManager.createNote(
            in: collectionID,
            libraryURL: libraryURL
        )

        if let noteID {
            ctx.selection.selectNote(noteID)
        }
    }
)
