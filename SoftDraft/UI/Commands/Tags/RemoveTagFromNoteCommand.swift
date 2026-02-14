//
//  RemoveTagFromNoteCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import Foundation
import SwiftUI

let removeTagFromNoteCommand = AppCommand(
    id: "tag.removeFromNote",
    title: "Remove Tag From Selected Note",
    shortcut: nil,
    isEnabled: { ctx, arguments in
        ctx.libraryURL != nil &&
        (arguments.noteID ?? ctx.selection.selectedNoteID) != nil &&
        arguments.tagID != nil
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let noteID = arguments.noteID ?? ctx.selection.selectedNoteID,
            let tagID = arguments.tagID
        else { return }

        guard var markdown = try? NoteStore.load(
            libraryURL: libraryURL,
            noteID: noteID
        ) else { return }

        let before = markdown
        markdown = removeTagOccurrences(
            from: markdown,
            tag: tagID
        )

        guard markdown != before else { return }

        ctx.libraryManager.beginInternalWrite(noteID: noteID)
        defer { ctx.libraryManager.endInternalWrite(noteID: noteID) }

        do {
            _ = try NoteStore.save(
                libraryURL: libraryURL,
                noteID: noteID,
                content: markdown
            )
            await ctx.libraryManager.reconcileSavedNoteImmediately(
                noteID: noteID,
                libraryURL: libraryURL
            )
        } catch {
            return
        }
    }
)

private func removeTagOccurrences(from markdown: String, tag: String) -> String {
    let escapedTag = NSRegularExpression.escapedPattern(for: tag)
    let pattern = "(^|[\\s\\(\\[{])#\(escapedTag)(?=$|[\\s\\.,!?:;\\)\\]}])"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return markdown
    }

    let nsRange = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
    var output = regex.stringByReplacingMatches(
        in: markdown,
        options: [],
        range: nsRange,
        withTemplate: "$1"
    )

    output = output.replacingOccurrences(
        of: #" {2,}"#,
        with: " ",
        options: .regularExpression
    )

    output = output.replacingOccurrences(
        of: #"[ \t]+\n"#,
        with: "\n",
        options: .regularExpression
    )

    return output
}
