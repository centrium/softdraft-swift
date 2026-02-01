import SwiftUI

struct NotePreviewSurface: View {

    let text: String

    @State private var renderedHTML = makePreviewHTML(body: NotePreviewSurface.placeholderBody)
    @State private var debounceTask: Task<Void, Never>?

    private static let placeholderBody = "<p>Start typing to see the preview.</p>"
    private let debounceDelay: UInt64 = 140_000_000 // ~140ms

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            PreviewWebView(html: renderedHTML)
        }
        .onAppear {
            renderImmediately(for: text)
        }
        .onChange(of: text) { _, newValue in
            scheduleRender(for: newValue)
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    private func scheduleRender(for value: String) {
        debounceTask?.cancel()

        let target = value
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                renderedHTML = makePreviewHTML(
                    body: makePreviewBody(from: target)
                )
            }
        }
    }

    private func renderImmediately(for value: String) {
        renderedHTML = makePreviewHTML(
            body: makePreviewBody(from: value)
        )
    }

    private func makePreviewBody(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.placeholderBody
        }

        let escaped = escapeHTML(text)

        // Collapses double newlines into paragraphs while preserving any
        // single newlines within a paragraph as soft breaks.
        return escaped
            .components(separatedBy: "\n\n")
            .map { component in
                let body = component.replacingOccurrences(of: "\n", with: "<br />")
                return "<p>\(body)</p>"
            }
            .joined()
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
