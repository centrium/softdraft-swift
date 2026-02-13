//
//  CancelPendingCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 24/01/2026.
//
import SwiftUI

let cancelPendingCommand = AppCommand(
    id: "command.cancel",
    title: "Cancel",
    shortcut: KeyboardShortcut(.escape),
    isEnabled: { ctx in
        ctx.selection.pendingMove != nil
    },
    perform: { ctx in
        ctx.selection.pendingMove = nil
        ctx.uiState.requestNotesListFocus()
    }
)
