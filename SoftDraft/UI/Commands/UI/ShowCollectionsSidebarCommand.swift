//
//  ShowCollectionsSidebarCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let showCollectionsSidebarCommand = AppCommand(
    id: "sidebar.showCollections",
    title: "Show Collections Sidebar",
    shortcut: KeyboardShortcut("c", modifiers: [.command, .option]),
    isEnabled: { _ in true },
    perform: { ctx in
        ctx.uiState.sidebarMode = .collections
        ctx.libraryManager.enterCollectionMode()
        ctx.uiState.requestFocus(.sidebar)
    }
)
