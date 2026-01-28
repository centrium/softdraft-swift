//
//  TogglePinCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import SwiftUI

let togglePinCommand = AppCommand(
    id: "note.togglePin",
    title: "Toggle Pin",
    shortcut: KeyboardShortcut("p", modifiers: [.command]),
    isEnabled: { ctx in
        ctx.selection.selectedNoteID != nil && ctx.libraryURL != nil
    },
    perform: { ctx in
        print("Toggle Command being run")
        guard
            let noteID = ctx.selection.selectedNoteID,
            let libraryURL = ctx.libraryURL
        else { return }

        var meta = (try? LibraryMetaStore.load(libraryURL)) ?? LibraryMeta()

        let current = meta.pinned[noteID] ?? false
        meta.pinned[noteID] = !current

        await LibraryMetaStore.save(meta, to: libraryURL)

        ctx.libraryManager.reloadCurrentCollection()
    }
)
