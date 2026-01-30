//
//  ConfirmRenameCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//

import SwiftUI

let confirmRenameCollectionCommand = AppCommand(
    id: "collection.rename.confirm",
    title: "Confirm Rename",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.libraryURL != nil &&
        ctx.selection.pendingCollectionRename != nil &&
        isValidCollectionName(ctx.selection.collectionRenameDraft)
    },
    perform: { ctx in
        guard
            let libraryURL = ctx.libraryURL,
            let pending = ctx.selection.pendingCollectionRename
        else { return }

        let newName = ctx.selection.collectionRenameDraft

        await ctx.libraryManager.renameCollection(
            from: pending.originalID,
            to: newName,
            libraryURL: libraryURL
        )

        ctx.selection.cancelRenameCollection()
        ctx.selection.selectCollection(newName)
    }
)
