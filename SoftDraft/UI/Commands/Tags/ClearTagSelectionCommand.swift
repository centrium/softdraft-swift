//
//  ClearTagSelectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let clearTagSelectionCommand = AppCommand(
    id: "tag.clearSelection",
    title: "Clear Tag Selection",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.libraryManager.visibleTag != nil
    },
    perform: { ctx in
        ctx.libraryManager.clearTagSelection()
    }
)
