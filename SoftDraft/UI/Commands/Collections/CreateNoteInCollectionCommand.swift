//
//  CreateNoteInCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let createNoteInCollectionCommand = AppCommand(
    id: "note.createInCollection",
    title: "New Note in Collection",
    shortcut: nil,
    isEnabled: { ctx, arguments in
        guard ctx.libraryURL != nil else { return false }
        return (arguments.collectionID ?? ctx.selection.selectedCollectionID) != nil
    },
    perform: { ctx, arguments in
        guard let libraryURL = ctx.libraryURL else { return }

        let collectionID =
            arguments.collectionID
            ?? ctx.selection.selectedCollectionID
            ?? "Inbox"

        ctx.selection.selectCollection(collectionID)

        let noteID = await ctx.libraryManager.createNote(
            in: collectionID,
            libraryURL: libraryURL
        )

        if let noteID {
            ctx.selection.selectNote(noteID)
            ctx.uiState.isPreviewModeEnabled = false
            ctx.uiState.requestFocus(.editor)
        }
    }
)
