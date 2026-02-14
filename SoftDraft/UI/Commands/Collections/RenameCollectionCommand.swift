//
//  RenameCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let renameCollectionCommand = AppCommand(
    id: "collection.rename",
    title: "Rename Collection",
    shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]),
    isEnabled: { ctx, arguments in
        guard
            let collectionID = arguments.collectionID ?? ctx.selection.selectedCollectionID
        else { return false }

        guard ctx.libraryURL != nil else { return false }
        return ctx.libraryManager.canRenameCollection(collectionID)
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let collectionID = arguments.collectionID ?? ctx.selection.selectedCollectionID,
            ctx.libraryManager.canRenameCollection(collectionID)
        else { return }

        let enteredName: String?
        if let value = arguments.textValue {
            enteredName = value
        } else {
            enteredName = await MainActor.run {
                promptForText(
                    title: "Rename Collection",
                    message: "Enter a new name.",
                    defaultValue: collectionID,
                    actionTitle: "Rename"
                )
            }
        }

        guard let enteredName else { return }
        let trimmedName = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidCollectionName(trimmedName) else { return }
        guard trimmedName != collectionID else { return }

        await ctx.libraryManager.renameCollection(
            from: collectionID,
            to: trimmedName,
            libraryURL: libraryURL
        )
        ctx.selection.selectCollection(trimmedName)
    }
)
