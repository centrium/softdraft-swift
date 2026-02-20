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

    func canExecute(
        _ id: CommandID,
        arguments: CommandArguments
    ) -> Bool {
        commands[id]?.isEnabled(context, arguments: arguments) ?? false
    }

    func run(_ id: CommandID) {
        guard let command = commands[id],
              command.isEnabled(context)
        else { return }

        Task {
            await command.perform(context)
        }
    }

    func run(
        _ id: CommandID,
        arguments: CommandArguments
    ) {
        guard let command = commands[id],
              command.isEnabled(context, arguments: arguments)
        else { return }

        Task {
            await command.perform(context, arguments: arguments)
        }
    }

    private func registerDefaults() {
        register(selectNoteCommand)
        register(setStateCommand)
        register(cycleNoteStateCommand)
        register(setNoteStateToDraftingCommand)
        register(setNoteStateToRefiningCommand)
        register(setNoteStateToFinishedCommand)
        register(setNoteStateFilterCommand)
        register(clearNoteStateFilterCommand)
        register(cycleNoteStateFilterCommand)
        register(duplicateNoteCommand)
        register(revealNoteInFinderCommand)
        register(togglePinCommand)
        register(moveNoteCommand)
        register(confirmMoveNoteCommand)
        register(cancelPendingCommand)
        register(createNoteCommand)
        register(deleteNoteCommand)
        register(createNoteInCollectionCommand)
        register(createCollectionCommand)
        register(selectCollectionCommand)
        register(renameCollectionCommand)
        register(beginRenameCollectionCommand)
        register(confirmRenameCollectionCommand)
        register(cancelRenameCollectionCommand)
        register(deleteCollectionCommand)
        register(expandCollectionsListCommand)
        register(collapseCollectionsListCommand)
        register(revealCollectionInFinderCommand)
        register(selectTagCommand)
        register(removeTagFromNoteCommand)
        register(clearTagSelectionCommand)
        register(createNewLibraryCommand)
        register(rebuildLibraryIndexCommand)
        register(toggleZenModeCommand)
        register(togglePreviewModeCommand)
        register(showCollectionsSidebarCommand)
        register(showTagsSidebarCommand)
        register(focusEditorCommand)
        register(cycleFocusForwardCommand)
        register(cycleFocusBackwardCommand)
        register(insertImageFromFileCommand)
        register(handlePasteCommand)
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

        context.selection.$pendingMove
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.selection.$pendingCollectionRename
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.uiState.$sidebarMode
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.uiState.$isCollectionsListExpanded
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.uiState.$activeFocusRegion
            .sink { [weak self] _ in
                self?.scheduleContextChange()
            }
            .store(in: &cancellables)

        context.uiState.$noteStateFilter
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
