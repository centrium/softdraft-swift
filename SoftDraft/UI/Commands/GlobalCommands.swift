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
    }
}
