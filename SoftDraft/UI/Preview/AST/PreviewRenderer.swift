//
//  PreviewRenderer.swift
//  SoftDraft
//

import SwiftUI
import AppKit

struct PreviewRenderer: PreviewBlockRenderer, PreviewInlineRenderer {

    let colorScheme: ColorScheme

    // MARK: - Rhythm

    private let blockSpacing: CGFloat = 12
    private let paragraphSpacing: CGFloat = 8
    private let lineSpacing: CGFloat = 4
    private let listItemSpacing: CGFloat = 6

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

    private let markerWidth: CGFloat = 22

    // MARK: - Typography

    private let bodyFont = Font.system(size: 17, weight: .regular, design: .default)

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .semibold, design: .default)
        case 2: return .system(size: 20, weight: .semibold, design: .default)
        case 3: return .system(size: 18, weight: .medium, design: .default)
        default: return .system(size: 17, weight: .medium, design: .default)
        }
    }

    // MARK: - Block rendering (public entry)

    func renderBlock(_ block: MarkdownBlock) -> AnyView {
        renderBlock(block, depth: 0)
    }

    // MARK: - Block rendering (depth-aware)

    private func renderBlock(_ block: MarkdownBlock, depth: Int) -> AnyView {
        switch block {

        case .thematicBreak:
            return AnyView(
                ThematicBreakView()
                    .padding(.vertical, 4)
            )

        case .codeBlock(let language, let source):
            return AnyView(
                BlockCodeView(source: source, language: language)
                    .padding(.vertical, 2)
            )

        case .mathBlock(let source):
            return AnyView(
                BlockMathView(source: source)
                    .padding(.vertical, 2)
            )

        case .mermaidBlock(let source):
            return AnyView(
                BlockMermaidView(source: source)
                    .padding(.vertical, 2)
            )

        case .table(let table):
            return renderTable(table)

        case .document(let blocks):
            return AnyView(
                VStack(alignment: .leading, spacing: blockSpacing) {
                    ForEach(blocks.indices, id: \.self) { i in
                        renderBlock(blocks[i], depth: depth)
                    }
                }
            )

        case .paragraph(let inlines):
            return AnyView(
                Text(renderInlineGroup(inlines))
                    .font(bodyFont)
                    .lineSpacing(lineSpacing)
                    .padding(.bottom, paragraphSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dividerColor)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(children.indices, id: \.self) { i in
                            renderBlock(children[i], depth: depth)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, paragraphSpacing)
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
                    .padding(.top, 3)

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
            .font(bodyFont)
            .fontWeight(isHeader ? .semibold : .regular)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(tableTextAlignment(for: columnAlignment))
            .frame(maxWidth: .infinity, alignment: tableFrameAlignment(for: columnAlignment))
            .foregroundStyle(isHeader ? Color.primary : Color.primary)
            .padding(.vertical, listItemSpacing / 2)
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

        case .listItem:
            switch style {

            case .unordered:
                Text("•")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)

            case .ordered(let start):
                let number = start + index
                Text("\(number).")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Inline rendering

    func renderInline(_ inline: MarkdownInline) -> AttributedString {
        switch inline {

        case .mathInline(let source):
            var result = AttributedString(source)
            result.font = .system(.body, design: .monospaced)
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
            result.font = .system(.body, design: .monospaced)
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
