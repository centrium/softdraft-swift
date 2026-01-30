//
//  DeleteCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//


import SwiftUI

let deleteCollectionCommand = AppCommand(
    id: "collection.delete",
    title: "Delete Collection",
    shortcut: KeyboardShortcut(.delete, modifiers: [.command]),
    isEnabled: { ctx in
        guard
            let collectionID = ctx.selection.selectedCollectionID
        else { return false }

        return
            ctx.libraryURL != nil &&
            ctx.libraryManager.canRenameCollection(collectionID)
    },
    perform: { ctx in
        guard
            let libraryURL = ctx.libraryURL,
            let collectionID = ctx.selection.selectedCollectionID
        else { return }

        // If empty, delete immediately
        if !ctx.libraryManager.collectionHasNotes(collectionID, libraryURL: libraryURL) {
            await ctx.libraryManager.deleteCollection(
                collectionID,
                libraryURL: libraryURL
            )
            return
        }

        // Otherwise, confirm
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Delete “\(collectionID)”?"
            alert.informativeText =
                "This collection contains notes. Deleting it will permanently remove the collection and all its notes."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                Task {
                    await ctx.libraryManager.deleteCollection(
                        collectionID,
                        libraryURL: libraryURL
                    )
                }
            }
        }
    }
)
