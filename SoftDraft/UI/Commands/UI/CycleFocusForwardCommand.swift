//
//  CycleFocusForwardCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let cycleFocusForwardCommand = AppCommand(
    id: "focus.cycle.forward",
    title: "Focus Next Region",
    shortcut: KeyboardShortcut(.rightArrow, modifiers: [.command, .option]),
    isEnabled: { _ in true },
    perform: { ctx in
        let orderedRegions: [FocusRegion] = [.sidebar, .notesList, .editor]
        guard let currentIndex = orderedRegions.firstIndex(of: ctx.uiState.activeFocusRegion) else {
            ctx.uiState.requestFocus(.sidebar)
            return
        }

        let nextIndex = (currentIndex + 1) % orderedRegions.count
        let target = orderedRegions[nextIndex]
        if target == .editor {
            ctx.uiState.isPreviewModeEnabled = false
        }
        ctx.uiState.requestFocus(target)
    }
)
