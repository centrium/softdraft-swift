//
//  AppCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import SwiftUI

struct CommandArguments: Sendable {
    var noteID: String?
    var collectionID: String?
    var tagID: String?
    var textValue: String?
    var noteState: NoteState?
}

@MainActor
final class AppCommand {
    let id: CommandID
    let title: String
    let shortcut: KeyboardShortcut?
    private let enabledHandler: (CommandContext, CommandArguments) -> Bool
    private let performHandler: (CommandContext, CommandArguments) async -> Void

    init(
        id: CommandID,
        title: String,
        shortcut: KeyboardShortcut?,
        isEnabled: @escaping (CommandContext) -> Bool,
        perform: @escaping (CommandContext) async -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.enabledHandler = { context, _ in
            isEnabled(context)
        }
        self.performHandler = { context, _ in
            await perform(context)
        }
    }

    init(
        id: CommandID,
        title: String,
        shortcut: KeyboardShortcut?,
        isEnabled: @escaping (CommandContext, CommandArguments) -> Bool,
        perform: @escaping (CommandContext, CommandArguments) async -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.enabledHandler = isEnabled
        self.performHandler = perform
    }

    func isEnabled(_ context: CommandContext) -> Bool {
        enabledHandler(context, CommandArguments())
    }

    func isEnabled(_ context: CommandContext, arguments: CommandArguments) -> Bool {
        enabledHandler(context, arguments)
    }

    func perform(_ context: CommandContext) async {
        await performHandler(context, CommandArguments())
    }

    func perform(_ context: CommandContext, arguments: CommandArguments) async {
        await performHandler(context, arguments)
    }
}
