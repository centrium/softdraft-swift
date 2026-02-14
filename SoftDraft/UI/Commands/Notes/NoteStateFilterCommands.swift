//
//  NoteStateFilterCommands.swift
//  SoftDraft
//

import SwiftUI

let setNoteStateFilterCommand = AppCommand(
    id: "note.stateFilter.set",
    title: "Set Note State Filter",
    shortcut: nil,
    isEnabled: { _, arguments in
        arguments.noteState != nil
    },
    perform: { ctx, arguments in
        guard let noteState = arguments.noteState else { return }
        ctx.uiState.noteStateFilter = noteState
    }
)

let clearNoteStateFilterCommand = AppCommand(
    id: "note.stateFilter.clear",
    title: "Show All Note States",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.uiState.noteStateFilter != nil
    },
    perform: { ctx in
        ctx.uiState.noteStateFilter = nil
    }
)

let cycleNoteStateFilterCommand = AppCommand(
    id: "note.stateFilter.cycle",
    title: "Cycle Note State Filter",
    shortcut: KeyboardShortcut("f", modifiers: [.command, .option]),
    isEnabled: { ctx in
        ctx.libraryURL != nil
    },
    perform: { ctx in
        ctx.uiState.noteStateFilter = NoteStateFiltering.nextFilter(
            after: ctx.uiState.noteStateFilter
        )
    }
)
