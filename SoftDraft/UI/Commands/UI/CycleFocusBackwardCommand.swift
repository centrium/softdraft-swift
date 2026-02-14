//
//  CycleFocusBackwardCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let cycleFocusBackwardCommand = AppCommand(
    id: "focus.cycle.backward",
    title: "Focus Previous Region",
    shortcut: KeyboardShortcut(.leftArrow, modifiers: [.command, .option]),
    isEnabled: { _ in true },
    perform: { ctx in
        let orderedRegions: [FocusRegion] = [.sidebar, .notesList, .editor]
        guard let currentIndex = orderedRegions.firstIndex(of: ctx.uiState.activeFocusRegion) else {
            ctx.uiState.requestFocus(.sidebar)
            return
        }

        let previousIndex = (currentIndex - 1 + orderedRegions.count) % orderedRegions.count
        let target = orderedRegions[previousIndex]
        if target == .editor {
            ctx.uiState.isPreviewModeEnabled = false
        }
        ctx.uiState.requestFocus(target)
    }
)
