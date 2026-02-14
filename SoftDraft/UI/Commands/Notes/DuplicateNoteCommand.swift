//
//  DuplicateNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let duplicateNoteCommand = AppCommand(
    id: "note.duplicate",
    title: "Duplicate Note",
    shortcut: KeyboardShortcut("d", modifiers: [.command]),
    isEnabled: { ctx, arguments in
        ctx.libraryURL != nil &&
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let sourceNoteID = arguments.noteID ?? ctx.selection.selectedNoteID
        else { return }

        guard let sourceMarkdown = try? NoteStore.load(
            libraryURL: libraryURL,
            noteID: sourceNoteID
        ) else { return }

        let sourceCollection = ctx.libraryManager.collectionID(for: sourceNoteID)
        let sourceFilename = (sourceNoteID as NSString).lastPathComponent
        let sourceTitle =
            ctx.libraryManager.libraryIndex?.notes[sourceNoteID]?.title
            ?? MarkdownTitle.displayTitle(fromFilename: sourceFilename)
        let sourceState = ctx.libraryManager.noteState(noteID: sourceNoteID)

        ctx.libraryManager.beginInternalWrite()
        defer { ctx.libraryManager.endInternalWrite() }

        do {
            let created = try NoteStore.create(
                libraryURL: libraryURL,
                collection: sourceCollection,
                title: "\(sourceTitle) copy"
            )

            _ = try NoteStore.save(
                libraryURL: libraryURL,
                noteID: created.summary.id,
                content: sourceMarkdown
            )

            ctx.libraryManager.updateLibraryIndexAfterCreateNote(
                noteID: created.summary.id,
                title: created.summary.title,
                collectionID: sourceCollection
            )

            if let index = ctx.libraryManager.libraryIndex {
                ctx.libraryManager.libraryIndex = LibraryIndexMutator.updateNoteFromFilesystem(
                    index: index,
                    noteID: created.summary.id,
                    filesystemData: .init(modified: Date()),
                    libraryURL: libraryURL
                )
            }

            if sourceState != .drafting,
               let index = ctx.libraryManager.libraryIndex {
                ctx.libraryManager.libraryIndex = LibraryIndexMutator.setState(
                    index: index,
                    noteID: created.summary.id,
                    state: sourceState
                )
            }

            ctx.libraryManager.persistLibraryIndex(libraryURL: libraryURL)
            ctx.libraryManager.reloadCurrentCollection()
            ctx.selection.selectNote(created.summary.id)
            ctx.uiState.isPreviewModeEnabled = false
            ctx.uiState.requestFocus(.editor)
        } catch {
            return
        }
    }
)
