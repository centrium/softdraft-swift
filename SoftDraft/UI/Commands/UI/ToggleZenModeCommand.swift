//
//  ToggleZenModeCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//


import SwiftUI

let toggleZenModeCommand = AppCommand(
    id: "view.toggleZenMode",
    title: "Toggle Focus Mode",
    shortcut: KeyboardShortcut("f", modifiers: [.command, .shift]),
    isEnabled: { ctx in
        ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        withAnimation{
            ctx.uiState.isZenModeEnabled.toggle()
        }
    }
)
