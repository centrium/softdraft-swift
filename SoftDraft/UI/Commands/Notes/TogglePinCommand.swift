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
            let noteID = ctx.selection.selectedNoteID
        else { return }

        ctx.libraryManager.togglePin(noteID: noteID)
        ctx.libraryManager.reloadCurrentCollection()
    }
)
