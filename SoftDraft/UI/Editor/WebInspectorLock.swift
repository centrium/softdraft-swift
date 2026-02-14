//
//  WebInspectorLock.swift
//  SoftDraft
//

import SwiftUI
import WebKit

private struct WebInspectorLock: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyLock(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyLock(from: nsView)
    }

    private func applyLock(from anchor: NSView) {
        DispatchQueue.main.async {
            guard let root = anchor.window?.contentView else { return }
            disableInspection(in: root)
        }
    }

    private func disableInspection(in view: NSView) {
        if let webView = view as? WKWebView {
            if #available(macOS 13.3, *) {
                webView.isInspectable = false
            }
            webView.configuration.preferences.setValue(
                false,
                forKey: "developerExtrasEnabled"
            )
        }

        for subview in view.subviews {
            disableInspection(in: subview)
        }
    }
}

extension View {
    func lockEmbeddedWebInspectors() -> some View {
        background(
            WebInspectorLock()
                .frame(width: 0, height: 0)
        )
    }
}
