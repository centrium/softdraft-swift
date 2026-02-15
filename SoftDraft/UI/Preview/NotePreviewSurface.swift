import SwiftUI

struct NotePreviewSurface: View {
    
    let noteID: String?
    let text: String
    
    @State private var renderedView: AnyView = AnyView(Text(NotePreviewSurface.placeholderText))
    @State private var debounceTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var libraryManager: LibraryManager
    
    private static let placeholderText = ""
    private let debounceDelay: UInt64 = 140_000_000 // ~140ms
    private let parser = MarkdownASTParser()
    private let normalizer = MarkdownASTNormalizer()
    
    var body: some View {
        ZStack {
            AppTones.previewSurface(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                // Previously we constrained the renderer output here, which meant
                // any attempt to promote the first image never escaped the 680pt column.
                renderedView
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.vertical, 32)
            }
        }
        .textSelection(.enabled)
        .onAppear {
            print("Preview rendering noteID:", noteID ?? "nil")
            renderImmediately(for: text)
        }
        .onChange(of: noteID) { _, newValue in
            print("Preview rendering noteID:", newValue ?? "nil")
        }
        .onChange(of: text) { _, newValue in
            scheduleRender(for: newValue)
        }
        .onChange(of: colorScheme) { _, _ in
            renderImmediately(for: text)
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
            return AnyView(placeholderView)
        }
        
        let document = normalizer.normalize(parser.parse(text))
#if DEBUG
        MarkdownPreviewDiagnostics.dump(source: text, document: document)
#endif
        let renderer = PreviewRenderer(
            colorScheme: colorScheme,
            libraryURL: libraryManager.activeLibraryURL
        )
        
        // 👇 THIS is the key line
        return renderer.renderBlock(document.root)
    }

    private var placeholderView: some View {
        HStack {
            Spacer(minLength: 0)
            Text(Self.placeholderText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
private enum MarkdownPreviewDiagnostics {

    static func dump(source: String, document: MarkdownDocument) {
        print("=== Markdown Preview Diagnostics ===")
        print("Raw markdown (character count: \(source.count)):")
        print(String(reflecting: source))

        let blocks = rootBlocks(in: document)
        print("Top-level blocks: \(blocks.count)")

        var paragraphIndex = 0
        for (idx, block) in blocks.enumerated() {
            print("Block[\(idx)]: \(block.displayName)")
            block.dump(into: "  ")

            if case .paragraph(let inlines) = block {
                paragraphIndex += 1
                print("  Paragraph[\(paragraphIndex)] text: \(concatenatedText(inlines))")
            }
        }

        print("Total paragraphs: \(paragraphIndex)")
        print("=== End Markdown Diagnostics ===")
    }

    private static func rootBlocks(in document: MarkdownDocument) -> [MarkdownBlock] {
        if case .document(let blocks) = document.root {
            return blocks
        }
        return [document.root]
    }

    private static func concatenatedText(_ inlines: [MarkdownInline]) -> String {
        var result = ""
        for inline in inlines {
            switch inline {
            case .text(let value):
                result.append(value)
            case .tag(let value):
                result.append("#" + value)
            case .emphasis(let children),
                 .strong(let children),
                 .highlight(let children),
                 .strikethrough(let children):
                result.append(concatenatedText(children))
            case .inlineCode(let code):
                result.append(code)
            case .mathInline(let value):
                result.append(value)
            case .link(let link):
                result.append(concatenatedText(link.children))
            case .image(let image):
                result.append("![\(image.alt ?? "")]\(image.source)")
            }
        }
        return result
    }
}

private extension MarkdownBlock {
    var displayName: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading(let level, _): return "Heading(level: \(level))"
        case .blockQuote: return "BlockQuote"
        case .list(let style, _): return "List(\(style))"
        case .codeBlock(let language, _): return "CodeBlock(lang: \(language ?? "none"))"
        case .thematicBreak: return "ThematicBreak"
        case .table: return "Table"
        case .image: return "Image"
        case .mermaidBlock: return "Mermaid"
        case .mathBlock: return "MathBlock"
        case .document: return "Document"
        }
    }

    func dump(into indent: String) {
        switch self {
        case .document(let blocks):
            for block in blocks {
                print(indent + block.displayName)
                block.dump(into: indent + "  ")
            }
        case .paragraph(let inlines):
            print(indent + "Inlines: \(inlines.count)")
            for inline in inlines {
                print(indent + "  - \(inline.displayName)")
            }
        case .heading(_, let inlines):
            print(indent + "Heading inlines: \(inlines.count)")
        case .blockQuote(let children):
            print(indent + "Quote blocks: \(children.count)")
        case .list(_, let items):
            print(indent + "List items: \(items.count)")
        case .codeBlock(_, let source):
            print(indent + "Code length: \(source.count)")
        case .thematicBreak:
            break
        case .table(let table):
            print(indent + "Table rows: \(table.rows.count)")
        case .image(let image):
            print(indent + "Image alt: \(image.alt ?? "none")")
        case .mermaidBlock(let source):
            print(indent + "Mermaid length: \(source.count)")
        case .mathBlock(let source):
            print(indent + "Math length: \(source.count)")
        }
    }
}

private extension MarkdownInline {
    var displayName: String {
        switch self {
        case .text(let value): return "Text(\(value))"
        case .tag(let value): return "Tag(\(value))"
        case .emphasis: return "Emphasis"
        case .strong: return "Strong"
        case .inlineCode(let code): return "InlineCode(\(code))"
        case .link(let link): return "Link(\(link.destination))"
        case .image(let image): return "Image(\(image.source))"
        case .mathInline(let value): return "MathInline(\(value))"
        case .highlight: return "Highlight"
        case .strikethrough: return "Strikethrough"
        }
    }
}
#endif
