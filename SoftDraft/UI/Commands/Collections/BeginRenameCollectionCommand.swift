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
        ctx.libraryURL != nil &&
        ctx.selection.selectedCollectionID != nil &&
        ctx.selection.pendingCollectionRename == nil
    },
    perform: { ctx in
        guard let id = ctx.selection.selectedCollectionID else { return }
        ctx.selection.beginRenameCollection(id)
    }
)
