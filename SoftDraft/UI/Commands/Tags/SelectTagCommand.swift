//
//  SelectTagCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let selectTagCommand = AppCommand(
    id: "tag.select",
    title: "Show Tagged Notes",
    shortcut: nil,
    isEnabled: { _, arguments in
        arguments.tagID != nil
    },
    perform: { ctx, arguments in
        guard let tagID = arguments.tagID else { return }
        ctx.uiState.sidebarMode = .tags
        ctx.libraryManager.selectTag(tagID)
        ctx.uiState.requestFocus(.notesList)
    }
)
