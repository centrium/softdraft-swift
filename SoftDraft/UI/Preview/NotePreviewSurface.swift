import SwiftUI

struct NotePreviewSurface: View {

    let text: String

    @State private var renderedHTML = makePreviewHTML(body: NotePreviewSurface.placeholderBody)
    @State private var debounceTask: Task<Void, Never>?

    private static let placeholderBody = "<p>Start typing to see the preview.</p>"
    private let debounceDelay: UInt64 = 140_000_000 // ~140ms
    private let parser = MarkdownASTParser()

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

        let document = parser.parse(text)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonString: String
        if let data = try? encoder.encode(document),
           let decoded = String(data: data, encoding: .utf8) {
            jsonString = decoded
        } else {
            jsonString = "{\n  \"error\": \"Unable to encode AST\"\n}"
        }

        let escaped = escapeHTML(jsonString)
        return "<pre style=\"font-family: -apple-system-monospaced; white-space: pre-wrap;\">\(escaped)</pre>"
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
