import SwiftUI

struct NotePreviewSurface: View {
    
    let text: String
    
    @State private var renderedView: AnyView = AnyView(Text(NotePreviewSurface.placeholderText))
    @State private var debounceTask: Task<Void, Never>?
    
    private static let placeholderText = "Start typing to see the preview."
    private let debounceDelay: UInt64 = 140_000_000 // ~140ms
    private let parser = MarkdownASTParser()
    
    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()
            
            ScrollView {
                HStack {
                    Spacer(minLength: 0)
                    renderedView
                        .frame(maxWidth: 680, alignment: .leading)
                        .padding(24)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 32)
            }
        }
        .textSelection(.enabled)
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
    
    // MARK: - Rendering
    
    private func scheduleRender(for value: String) {
        debounceTask?.cancel()
        
        let target = value
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceDelay)
            guard !Task.isCancelled else { return }
            
            let rendered = renderAST(from: target)
            
            await MainActor.run {
                renderedView = rendered
            }
        }
    }
    
    private func renderImmediately(for value: String) {
        renderedView = renderAST(from: value)
    }
    
    private func renderAST(from text: String) -> AnyView {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AnyView(
                Text(Self.placeholderText)
                    .foregroundStyle(.secondary)
            )
        }
        
        let document = parser.parse(text)
        let renderer = PreviewRenderer()
        
        // 👇 THIS is the key line
        return renderer.renderBlock(document.root)
    }
}
