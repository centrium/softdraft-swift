//
//  BeginRenameCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//

import SwiftUI

let beginRenameCollectionCommand = AppCommand(
    id: "collection.rename.begin",
    title: "Rename Collection",
    shortcut: KeyboardShortcut("r", modifiers: [.command]),
    isEnabled: { ctx in
        guard
            let collectionID = ctx.selection.selectedCollectionID,
            ctx.libraryURL != nil,
            ctx.selection.pendingCollectionRename == nil
        else { return false }

        return ctx.libraryManager.canRenameCollection(collectionID)
    },
    perform: { ctx in
        guard let collectionID = ctx.selection.selectedCollectionID else { return }
        ctx.selection.beginRenameCollection(collectionID)
    }
)
