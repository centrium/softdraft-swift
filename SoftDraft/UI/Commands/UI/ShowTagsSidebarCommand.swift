//
//  ShowTagsSidebarCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let showTagsSidebarCommand = AppCommand(
    id: "sidebar.showTags",
    title: "Show Tags Sidebar",
    shortcut: KeyboardShortcut("t", modifiers: [.command, .option]),
    isEnabled: { _ in true },
    perform: { ctx in
        ctx.uiState.sidebarMode = .tags
        ctx.libraryManager.enterTagMode()
        ctx.uiState.requestFocus(.sidebar)
    }
)
