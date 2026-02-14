//
//  SetStateCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let setStateCommand = AppCommand(
    id: "note.setState",
    title: "Set State",
    shortcut: nil,
    isEnabled: { ctx, arguments in
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil &&
        arguments.noteState != nil
    },
    perform: { ctx, arguments in
        guard
            let noteID = arguments.noteID ?? ctx.selection.selectedNoteID,
            let noteState = arguments.noteState
        else { return }

        ctx.libraryManager.setNoteState(
            noteID: noteID,
            state: noteState
        )
    }
)

let cycleNoteStateCommand = AppCommand(
    id: "note.state.cycle",
    title: "Cycle Note State",
    shortcut: KeyboardShortcut("s", modifiers: [.command, .option]),
    isEnabled: { ctx, arguments in
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil &&
        ctx.libraryURL != nil
    },
    perform: { ctx, arguments in
        guard let noteID = arguments.noteID ?? ctx.selection.selectedNoteID else { return }

        let currentState = ctx.libraryManager.noteState(noteID: noteID)
        ctx.libraryManager.setNoteState(
            noteID: noteID,
            state: currentState.next
        )
    }
)

private func makeSetSpecificNoteStateCommand(
    id: CommandID,
    title: String,
    state: NoteState,
    shortcut: KeyboardShortcut
) -> AppCommand {
    AppCommand(
        id: id,
        title: title,
        shortcut: shortcut,
        isEnabled: { ctx, arguments in
            (arguments.noteID ?? ctx.selection.selectedNoteID) != nil &&
            ctx.libraryURL != nil
        },
        perform: { ctx, arguments in
            guard let noteID = arguments.noteID ?? ctx.selection.selectedNoteID else { return }
            ctx.libraryManager.setNoteState(
                noteID: noteID,
                state: state
            )
        }
    )
}

let setNoteStateToDraftingCommand = makeSetSpecificNoteStateCommand(
    id: "note.state.setDrafting",
    title: "Set State to Drafting",
    state: .drafting,
    shortcut: KeyboardShortcut("1", modifiers: [.option])
)

let setNoteStateToRefiningCommand = makeSetSpecificNoteStateCommand(
    id: "note.state.setRefining",
    title: "Set State to Refining",
    state: .refining,
    shortcut: KeyboardShortcut("2", modifiers: [.option])
)

let setNoteStateToFinishedCommand = makeSetSpecificNoteStateCommand(
    id: "note.state.setFinished",
    title: "Set State to Finished",
    state: .finished,
    shortcut: KeyboardShortcut("3", modifiers: [.option])
)
