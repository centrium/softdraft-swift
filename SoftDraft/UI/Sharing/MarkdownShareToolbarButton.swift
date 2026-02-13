//
//  MarkdownShareToolbarButton.swift
//  SoftDraft
//
//  Created by Matt Adams on 13/02/2026.
//

import SwiftUI
import AppKit

struct MarkdownShareToolbarButton: View {
    let markdown: String?

    var body: some View {
        SharingServicePickerButton(sharedText: markdown)
            .disabled(markdown == nil)
    }
}

private struct SharingServicePickerButton: NSViewRepresentable {
    let sharedText: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: "",
            target: context.coordinator,
            action: #selector(Coordinator.showPicker(_:))
        )
        button.image = NSImage(named: NSImage.shareTemplateName)
            ?? NSImage(
                systemSymbolName: "square.and.arrow.up",
                accessibilityDescription: "Share"
            )
        button.imagePosition = .imageOnly
        button.bezelStyle = .toolbar
        button.setAccessibilityLabel("Share")
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.sharedText = sharedText
        nsView.isEnabled = sharedText != nil
    }

    final class Coordinator: NSObject {
        var sharedText: String?

        @objc
        func showPicker(_ sender: NSButton) {
            guard let sharedText else { return }
            let picker = NSSharingServicePicker(items: [sharedText])
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
