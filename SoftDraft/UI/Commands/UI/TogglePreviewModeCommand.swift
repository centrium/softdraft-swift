//
//  TogglePreviewModeCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 01/02/2026.
//

import SwiftUI

let togglePreviewModeCommand = AppCommand(
    id: "view.togglePreviewMode",
    title: "Toggle Preview Mode",
    shortcut: KeyboardShortcut("p", modifiers: [.command, .shift]),
    isEnabled: { ctx in
        ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        withAnimation(.easeInOut(duration: 0.25)) {
            ctx.uiState.isPreviewModeEnabled.toggle()
        }
    }
)
