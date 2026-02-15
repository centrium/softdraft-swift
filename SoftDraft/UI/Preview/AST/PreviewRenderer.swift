//
//  PreviewRenderer.swift
//  SoftDraft
//

import SwiftUI
import AppKit

struct PreviewRenderer: PreviewBlockRenderer, PreviewInlineRenderer {

    let colorScheme: ColorScheme
    let libraryURL: URL?

    // MARK: - Rhythm

    private let blockSpacing: CGFloat = 12
    private let paragraphSpacing: CGFloat = 8
    private let lineSpacing: CGFloat = 5
    private let listItemSpacing: CGFloat = 8
    private let coverSpacing: CGFloat = 24
    private let bodyWidth: CGFloat = 680
    private let bodyHorizontalPadding: CGFloat = 24

    // MARK: - Nesting guide

    private let nestingGuideWidth: CGFloat = 1

    private var dividerColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(colorScheme == .dark ? 0.9 : 1)
    }

    private var taskListBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    // MARK: - List layout

    private let markerWidth: CGFloat = 24

    // MARK: - Typography

    private let bodyFont = AppTypography.body

    private func headingFont(for level: Int) -> Font {
        AppTypography.previewHeading(for: level)
    }

    // MARK: - Block rendering (public entry)

    func renderBlock(_ block: MarkdownBlock) -> AnyView {
        renderBlock(block, depth: 0)
    }

    // MARK: - Block rendering (depth-aware)

    private func renderBlock(_ block: MarkdownBlock, depth: Int) -> AnyView {
        switch block {
            
        case .image(let image):
            return AnyView(
                BlockImageView(image: image, libraryURL: libraryURL)
                    .padding(.bottom, paragraphSpacing)
            )

        case .thematicBreak:
            return AnyView(ThematicBreakView())

        case .codeBlock(let language, let source):
            return AnyView(BlockCodeView(source: source, language: language))

        case .mathBlock(let source):
            return AnyView(BlockMathView(source: source))

        case .mermaidBlock(let source):
            return AnyView(BlockMermaidView(source: source))

        case .table(let table):
            return renderTable(table)

        case .document(let blocks):
            let context = documentContext(for: blocks)
            return AnyView(
                PreviewDocumentView(
                    bodyBlocks: context.bodyBlocks,
                    depth: depth,
                    coverContext: context.cover,
                    blockSpacing: blockSpacing,
                    coverSpacing: coverSpacing,
                    bodyWidth: bodyWidth,
                    bodyPadding: bodyHorizontalPadding,
                    libraryURL: libraryURL,
                    renderBlock: { block, nestedDepth in
                        renderBlock(block, depth: nestedDepth)
                    },
                    renderCoverHeadline: { block in
                        renderCoverHeadline(for: block)
                    }
                )
                .focusable(false)
            )

        case .paragraph(let inlines):
            return AnyView(
                Text(renderInlineGroup(inlines))
                    .font(bodyFont)
                    .lineSpacing(lineSpacing)
                    .padding(.bottom, paragraphSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            )

        case .heading(let level, let inlines):
            return AnyView(
                Text(renderInlineGroup(inlines))
                    .font(headingFont(for: level))
                    .lineSpacing(lineSpacing)
                    .padding(.top, blockSpacing)
                    .padding(.bottom, paragraphSpacing)
            )

        case .blockQuote(let children):
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(children.indices, id: \.self) { i in
                        renderBlock(children[i], depth: depth)
                    }
                }
                // indent the quote content
                .padding(.leading, 16)
                // draw the quote bar WITHOUT affecting layout width
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(width: 4)
                }
                .padding(.bottom, paragraphSpacing)
                .font(bodyFont)
            )

        case .list(let style, let items):
            let isTaskList = items.allSatisfy { entry in
                if case .taskItem = entry { return true }
                return false
            }

            let listContent = VStack(alignment: .leading, spacing: listItemSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    renderListItem(
                        item,
                        index: index,
                        style: style,
                        depth: depth
                    )
                }
            }
            .padding(.leading, depth > 0 ? 16 : 0)
            .background(alignment: .leading) {
                nestingGuide(for: depth)
            }

            let decorated: AnyView
            if isTaskList {
                decorated = AnyView(
                    listContent
                        .padding(.horizontal, blockSpacing)
                        .padding(.vertical, blockSpacing)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(taskListBackground)
                        )
                )
            } else {
                decorated = AnyView(listContent)
            }

            return AnyView(
                decorated
                    .padding(.bottom, paragraphSpacing)
            )

        default:
            return AnyView(DebugFallbackBlockView(block: block))
        }
    }

    // MARK: - Cover helpers

    private func documentContext(for blocks: [MarkdownBlock]) -> DocumentContext {
        guard !blocks.isEmpty else {
            return DocumentContext(cover: nil, bodyBlocks: [])
        }

        if case .image(let image) = blocks.first {
            let remainder = Array(blocks.dropFirst())
            let cover = CoverPresentation(
                block: blocks[0],
                image: image,
                headlineIndex: preferredHeadlineIndex(in: remainder)
            )
            return DocumentContext(cover: cover, bodyBlocks: remainder)
        }

        return DocumentContext(cover: nil, bodyBlocks: blocks)
    }

    private func preferredHeadlineIndex(in blocks: [MarkdownBlock]) -> Int? {
        guard !blocks.isEmpty else { return nil }

        if let firstH1 = blocks.firstIndex(where: { block in
            if case .heading(let level, _) = block, level == 1 {
                return true
            }
            return false
        }) {
            return firstH1
        }

        if let fallbackHeading = blocks.firstIndex(where: { block in
            if case .heading = block { return true }
            return false
        }) {
            return fallbackHeading
        }

        return nil
    }

    private func renderCoverHeadline(for block: MarkdownBlock) -> AnyView {
        guard case .heading(_, let inlines) = block else {
            return renderBlock(block, depth: 0)
        }

        let content = Text(renderInlineGroup(inlines))
            .font(AppTypography.primaryTitle)
            .lineSpacing(lineSpacing + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, paragraphSpacing + 16)

        return AnyView(content)
    }

    // MARK: - List items

    private func renderListItem(
        _ entry: MarkdownListEntry,
        index: Int,
        style: MarkdownListStyle,
        depth: Int
    ) -> AnyView {

        AnyView(
            HStack(alignment: .top, spacing: 8) {

                listMarker(for: entry, index: index, style: style)
                    .frame(width: markerWidth, alignment: .trailing)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: listItemSpacing) {
                    switch entry {

                    case .taskItem(let item):
                        ForEach(item.blocks.indices, id: \.self) { i in
                            renderBlock(item.blocks[i], depth: depth + 1)
                        }

                    case .listItem(let item):
                        ForEach(item.blocks.indices, id: \.self) { i in
                            renderBlock(item.blocks[i], depth: depth + 1)
                        }
                    }
                }
            }
        )
    }

    private func renderTable(_ table: MarkdownTable) -> AnyView {
        let columnCount = max(
            table.header?.cells.count ?? 0,
            table.rows.map { $0.cells.count }.max() ?? 0
        )

        guard columnCount > 0 else {
            return AnyView(EmptyView().padding(.bottom, paragraphSpacing))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: listItemSpacing) {
                if let header = table.header {
                    HStack(alignment: .firstTextBaseline, spacing: blockSpacing) {
                        ForEach(0..<columnCount, id: \.self) { column in
                            tableCell(
                                for: header,
                                column: column,
                                alignments: table.alignments,
                                isHeader: true
                            )
                        }
                    }
                    .padding(.bottom, listItemSpacing)
                    .overlay(alignment: .bottomLeading) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(dividerColor)
                    }
                }

                VStack(alignment: .leading, spacing: listItemSpacing) {
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: blockSpacing) {
                            ForEach(0..<columnCount, id: \.self) { column in
                                tableCell(
                                    for: row,
                                    column: column,
                                    alignments: table.alignments,
                                    isHeader: false
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, listItemSpacing)
            .padding(.bottom, paragraphSpacing)
        )
    }

    @ViewBuilder
    private func tableCell(
        for row: MarkdownTableRow,
        column: Int,
        alignments: [MarkdownTableAlignment],
        isHeader: Bool
    ) -> some View {
        let inlines = column < row.cells.count ? row.cells[column] : []

        let attributed = renderInlineGroup(inlines)
        let columnAlignment = tableAlignment(for: column, alignments: alignments)

        Text(attributed)
            .font(isHeader ? AppTypography.bodyEmphasis : bodyFont)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(tableTextAlignment(for: columnAlignment))
            .frame(maxWidth: .infinity, alignment: tableFrameAlignment(for: columnAlignment))
            .foregroundStyle(isHeader ? Color.primary : Color.primary)
            .padding(.vertical, 4)
    }

    private func tableAlignment(
        for column: Int,
        alignments: [MarkdownTableAlignment]
    ) -> MarkdownTableAlignment {
        guard column < alignments.count else { return .left }
        return alignments[column]
    }

    private func tableFrameAlignment(
        for alignment: MarkdownTableAlignment
    ) -> Alignment {
        switch alignment {
        case .left, .unspecified:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    private func tableTextAlignment(
        for alignment: MarkdownTableAlignment
    ) -> TextAlignment {
        switch alignment {
        case .left, .unspecified:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    @ViewBuilder
    private func nestingGuide(for depth: Int) -> some View {
        if depth > 0 {
            Capsule()
                .fill(dividerColor.opacity(0.5))
                .frame(width: nestingGuideWidth)
                .frame(maxHeight: .infinity)
                .padding(.vertical, blockSpacing)
        }
    }

    // MARK: - List markers

    @ViewBuilder
    private func listMarker(
        for entry: MarkdownListEntry,
        index: Int,
        style: MarkdownListStyle
    ) -> some View {

        switch entry {

        case .taskItem(let item):
            Image(systemName: item.checked ? "checkmark.square" : "square")
                .font(AppTypography.secondaryBody)
                .foregroundStyle(.secondary)

        case .listItem:
            switch style {

            case .unordered:
                Text("•")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)

            case .ordered(let start):
                let number = start + index
                Text("\(number).")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Inline rendering

    func renderInline(_ inline: MarkdownInline) -> AttributedString {
        switch inline {

        case .mathInline(let source):
            var result = AttributedString(source)
            result.font = AppTypography.monospacedBody
            return result

        case .text(let value):
            return AttributedString(value)

        case .emphasis(let children):
            var result = renderInlineGroup(children)
            result.font = bodyFont.italic()
            return result

        case .strong(let children):
            var result = renderInlineGroup(children)
            result.font = bodyFont.weight(.semibold)
            return result

        case .highlight(let children):
            var result = renderInlineGroup(children)
            result.backgroundColor = .yellow.opacity(0.25)
            return result

        case .inlineCode(let code):
            var result = AttributedString(code)
            result.font = AppTypography.monospacedBody
            result.backgroundColor = Color(nsColor: .controlBackgroundColor)
            return result

        case .strikethrough(let children):
            var result = renderInlineGroup(children)
            result.strikethroughStyle = .single
            result.foregroundColor = Color.secondary
            return result

        case .link(let link):
            var result = renderInlineGroup(link.children)
            if let url = URL(string: link.destination) {
                result.link = url
            }
            result.foregroundColor = Color.accentColor.opacity(0.9)
            result.underlineStyle = Text.LineStyle.single
            return result
        case .tag(let name):
            var attr = AttributedString("#\(name)")
            attr.font = AppTypography.bodyEmphasis
            attr.foregroundColor = Color(red: 0.50, green: 0.39, blue: 0.38)
            return attr

        default:
            return AttributedString("[inline]")
        }
    }

    func renderInlineGroup(_ inlines: [MarkdownInline]) -> AttributedString {
        var result = AttributedString()
        for inline in inlines {
            result += renderInline(inline)
        }
        return result
    }
}

// MARK: - Document container
private struct DocumentContext {
    let cover: CoverPresentation?
    let bodyBlocks: [MarkdownBlock]
}

private struct CoverPresentation: Equatable {
    let block: MarkdownBlock
    let image: MarkdownImage
    let headlineIndex: Int?
}

private struct PreviewDocumentView: View {

    let bodyBlocks: [MarkdownBlock]
    let depth: Int
    let coverContext: CoverPresentation?
    let blockSpacing: CGFloat
    let coverSpacing: CGFloat
    let bodyWidth: CGFloat
    let bodyPadding: CGFloat
    let libraryURL: URL?
    let renderBlock: (MarkdownBlock, Int) -> AnyView
    let renderCoverHeadline: (MarkdownBlock) -> AnyView

    @State private var coverVisibility: CoverVisibility

    init(
        bodyBlocks: [MarkdownBlock],
        depth: Int,
        coverContext: CoverPresentation?,
        blockSpacing: CGFloat,
        coverSpacing: CGFloat,
        bodyWidth: CGFloat,
        bodyPadding: CGFloat,
        libraryURL: URL?,
        renderBlock: @escaping (MarkdownBlock, Int) -> AnyView,
        renderCoverHeadline: @escaping (MarkdownBlock) -> AnyView
    ) {
        self.bodyBlocks = bodyBlocks
        self.depth = depth
        self.coverContext = coverContext
        self.blockSpacing = blockSpacing
        self.coverSpacing = coverSpacing
        self.bodyWidth = bodyWidth
        self.bodyPadding = bodyPadding
        self.libraryURL = libraryURL
        self.renderBlock = renderBlock
        self.renderCoverHeadline = renderCoverHeadline
        _coverVisibility = State(initialValue: coverContext == nil ? .failed : .pending)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let coverContext, coverVisibility != .failed {
                CoverImageView(
                    image: coverContext.image,
                    libraryURL: libraryURL,
                    visibility: $coverVisibility
                )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, coverVisibility == .visible ? coverSpacing : 0)
            }

            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: blockSpacing) {
                    if let coverContext, coverVisibility == .failed {
                        renderBlock(coverContext.block, depth)
                    }

                    ForEach(Array(bodyBlocks.enumerated()), id: \.offset) { index, block in
                        if let coverContext,
                           let headlineIndex = coverContext.headlineIndex,
                           index == headlineIndex,
                           case .heading = block {
                            renderCoverHeadline(block)
                        } else {
                            renderBlock(block, depth)
                        }
                    }
                }
                .frame(maxWidth: bodyWidth, alignment: .leading)
                .padding(.horizontal, bodyPadding)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: coverContext) { _, newValue in
            coverVisibility = newValue == nil ? .failed : .pending
        }
    }
}
