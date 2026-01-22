//
//  CommandRegisty.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation
import Combine

@MainActor
final class CommandRegistry: ObservableObject {

    private var commands: [CommandID: AppCommand] = [:]
    let context: CommandContext
    private var cancellables: Set<AnyCancellable> = []

    init(context: CommandContext) {
        self.context = context
        observeContext()
        registerDefaults()
    }

    func register(_ command: AppCommand) {
        commands[command.id] = command
    }

    func canExecute(_ id: CommandID) -> Bool {
        commands[id]?.isEnabled(context) ?? false
    }

    func run(_ id: CommandID) {
        guard let command = commands[id],
              command.isEnabled(context)
        else { return }

        Task {
            await command.perform(context)
        }
    }

    private func registerDefaults() {
        register(togglePinCommand)
        // others come later
    }

    private func observeContext() {
        context.selection.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        context.libraryManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
