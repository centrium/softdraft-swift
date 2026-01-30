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
    // Ticking value that forces SwiftUI to refresh command availability.
    @Published private var contextChangeTick: UInt = 0

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
        register(moveNoteCommand)
        register(confirmMoveNoteCommand)
        register(cancelPendingCommand)
        register(createNoteCommand)
        register(deleteNoteCommand)
        register(createCollectionCommand)
        register(beginRenameCollectionCommand)
        register(confirmRenameCollectionCommand)
        register(cancelRenameCollectionCommand)
        register(deleteCollectionCommand)
        register(toggleZenModeCommand)
        // others come later
    }

    private func observeContext() {
        context.selection.$selectedNoteID
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.libraryManager.$activeLibraryURL
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)
        
        context.selection.$selectedCollectionID
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)
    }

    private func scheduleContextChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contextChangeTick &+= 1
        }
    }
}
