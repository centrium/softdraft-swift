//
//  CommandPrompts.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import AppKit

@MainActor
func promptForText(
    title: String,
    message: String,
    defaultValue: String,
    actionTitle: String
) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: actionTitle)
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(string: defaultValue)
    textField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
    alert.accessoryView = textField

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else { return nil }
    return textField.stringValue
}
