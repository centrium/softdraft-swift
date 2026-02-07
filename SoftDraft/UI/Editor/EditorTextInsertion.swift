//
//  EditorTextInsertion.swift
//  SoftDraft
//

import AppKit

enum EditorTextInsertion {

    @MainActor
    static func insertMarkdown(_ markdown: String) -> Bool {
        guard !markdown.isEmpty else { return true }
        return NSApp.sendAction(
            #selector(NSText.insertText(_:)),
            to: nil,
            from: markdown
        )
    }

    @MainActor
    static func paste() {
        NSApp.sendAction(
            #selector(NSText.paste(_:)),
            to: nil,
            from: nil
        )
    }

    @MainActor
    static func cut() {
        NSApp.sendAction(
            #selector(NSText.cut(_:)),
            to: nil,
            from: nil
        )
    }

    @MainActor
    static func copy() {
        NSApp.sendAction(
            #selector(NSText.copy(_:)),
            to: nil,
            from: nil
        )
    }

    @MainActor
    static func selectAll() {
        NSApp.sendAction(
            #selector(NSText.selectAll(_:)),
            to: nil,
            from: nil
        )
    }
}

