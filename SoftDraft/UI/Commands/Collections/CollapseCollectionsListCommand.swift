//
//  CollapseCollectionsListCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let collapseCollectionsListCommand = AppCommand(
    id: "collection.list.collapse",
    title: "Collapse Collections List",
    shortcut: KeyboardShortcut(.upArrow, modifiers: [.command, .option]),
    isEnabled: { ctx in
        ctx.uiState.sidebarMode == .collections &&
        ctx.uiState.isCollectionsListExpanded
    },
    perform: { ctx in
        guard ctx.uiState.sidebarMode == .collections else { return }
        guard ctx.uiState.isCollectionsListExpanded else { return }
        ctx.uiState.isCollectionsListExpanded = false
        ctx.uiState.requestFocus(.sidebar)
    }
)
