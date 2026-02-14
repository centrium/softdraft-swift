//
//  SelectNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let selectNoteCommand = AppCommand(
    id: "note.select",
    title: "Select Note",
    shortcut: nil,
    isEnabled: { _, arguments in
        arguments.noteID != nil
    },
    perform: { ctx, arguments in
        guard let noteID = arguments.noteID else { return }

        if ctx.uiState.sidebarMode == .collections {
            let collectionID = ctx.libraryManager.collectionID(for: noteID)
            if ctx.selection.selectedCollectionID != collectionID {
                ctx.selection.selectCollection(collectionID)
            }
        }

        ctx.selection.selectNote(noteID)
    }
)
