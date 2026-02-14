//
//  GlobalCommands.swift
//  SoftDraft
//
//  Created by Matt Adams on 24/01/2026.
//

import SwiftUI

struct GlobalCommands: Commands {

    let commandRegistry: CommandRegistry
    
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Cancel Pending Action") {
                commandRegistry.run("command.cancel")
            }
            .keyboardShortcut(.escape, modifiers: [])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                Task { EditorTextInsertion.cut() }
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button("Copy") {
                Task { EditorTextInsertion.copy() }
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button("Paste") {
                commandRegistry.run("edit.paste")
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button("Select All") {
                Task { EditorTextInsertion.selectAll() }
            }
            .keyboardShortcut("a", modifiers: [.command])
        }
    }
}
