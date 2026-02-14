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
    shortcut: KeyboardShortcut("p", modifiers: [.command, .shift]),
    isEnabled: { ctx, arguments in
        ctx.libraryURL != nil &&
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil
    },
    perform: { ctx, arguments in
        guard let noteID = arguments.noteID ?? ctx.selection.selectedNoteID else { return }

        ctx.libraryManager.togglePin(noteID: noteID)
        ctx.libraryManager.reloadCurrentCollection()
    }
)
