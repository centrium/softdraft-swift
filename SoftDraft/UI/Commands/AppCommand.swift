//
//  AppCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import SwiftUI

struct AppCommand {
    let id: CommandID
    let title: String
    let shortcut: KeyboardShortcut?
    let isEnabled: (CommandContext) -> Bool
    let perform: (CommandContext) async -> Void
}

