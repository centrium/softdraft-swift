//
//  RevealNoteInFinderCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import AppKit
import SwiftUI

let revealNoteInFinderCommand = AppCommand(
    id: "note.revealInFinder",
    title: "Reveal in Finder",
    shortcut: nil,
    isEnabled: { ctx, arguments in
        ctx.libraryURL != nil &&
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let noteID = arguments.noteID ?? ctx.selection.selectedNoteID
        else { return }

        let noteURL = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)
            .appendingPathComponent(noteID)
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([noteURL])
        }
    }
)
