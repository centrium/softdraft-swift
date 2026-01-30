//
//  CreateCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//

import SwiftUI

let createCollectionCommand = AppCommand(
    id: "collection.create",
    title: "New Collection",
    shortcut: KeyboardShortcut("n", modifiers: [.command, .shift]),
    isEnabled: { ctx in
        ctx.libraryURL != nil
    },
    perform: { ctx in
        guard let libraryURL = ctx.libraryURL else { return }

        let collectionID = await ctx.libraryManager.createCollection(
            libraryURL: libraryURL
        )

        if let collectionID {
            ctx.selection.selectCollection(collectionID)
        }
    }
)
