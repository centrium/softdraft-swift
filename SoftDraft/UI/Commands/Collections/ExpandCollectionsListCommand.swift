//
//  ExpandCollectionsListCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let expandCollectionsListCommand = AppCommand(
    id: "collection.list.expand",
    title: "Expand Collections List",
    shortcut: KeyboardShortcut(.downArrow, modifiers: [.command, .option]),
    isEnabled: { ctx in
        ctx.uiState.sidebarMode == .collections &&
        !ctx.uiState.isCollectionsListExpanded
    },
    perform: { ctx in
        guard ctx.uiState.sidebarMode == .collections else { return }
        guard !ctx.uiState.isCollectionsListExpanded else { return }
        withAnimation(AppMotion.standard) {
            ctx.uiState.isCollectionsListExpanded = true
        }
        ctx.uiState.requestFocus(.sidebar)
    }
)
