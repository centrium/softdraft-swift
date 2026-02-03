//
//  PreviewRenderer.swift
//  SoftDraft
//
//  Created by Matt Adams on 02/02/2026.
//

import SwiftUI
import AppKit

struct PreviewRenderer: PreviewBlockRenderer, PreviewInlineRenderer {

    // MARK: - Blocks

    func renderBlock(_ block: MarkdownBlock) -> AnyView {
        switch block {

        case .document(let blocks):
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks.indices, id: \.self) { i in
                        renderBlock(blocks[i])
                    }
                }
            )

        case .paragraph(let inlines):
            return AnyView(
                Text(renderInlineGroup(inlines))
            )

        case .heading(let level, let inlines):
            return AnyView(
                Text(renderInlineGroup(inlines))
                    .font(.system(size: headingSize(for: level), weight: .bold))
            )

        case .blockQuote(let children):
            return AnyView(
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .frame(width: 3)
                        .opacity(0.3)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(children.indices, id: \.self) { i in
                            renderBlock(children[i])
                        }
                    }
                }
            )

        case .list(_, let items):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        renderListItem(items[i])
                    }
                }
            )

        default:
            return AnyView(
                DebugFallbackBlockView(block: block)
            )
        }
    }

    // MARK: - List Items

    func renderListItem(_ entry: MarkdownListEntry) -> AnyView {
        switch entry {

        case .listItem(let item):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.blocks.indices, id: \.self) { i in
                        renderBlock(item.blocks[i])
                    }
                }
            )

        case .taskItem(let item):
            return AnyView(
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.checked ? "checkmark.square" : "square")
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(item.blocks.indices, id: \.self) { i in
                            renderBlock(item.blocks[i])
                        }
                    }
                }
            )
        }
    }

    // MARK: - Inline Rendering (AttributedString)

    func renderInline(_ inline: MarkdownInline) -> AttributedString {
        switch inline {

        case .text(let value):
            return AttributedString(value)

        case .emphasis(let children):
            var result = renderInlineGroup(children)
            result.font = .system(.body).italic()
            return result

        case .strong(let children):
            var result = renderInlineGroup(children)
            result.font = .system(.body).bold()
            return result
        
        case .highlight(let children):
            var result = renderInlineGroup(children)

            // Subtle, adaptive highlight
            result.backgroundColor = .yellow.opacity(0.35)

            return result

        case .inlineCode(let code):
            var result = AttributedString(" \(code) ")

            // Monospaced font
            result.font = .system(.body, design: .monospaced)

            // Adaptive colours (light & dark safe)
            result.foregroundColor = .secondary
            result.backgroundColor = .secondary.opacity(0.2)

            return result
        
        case .strikethrough(let children):
            var result = renderInlineGroup(children)
            result.strikethroughStyle = .single
            return result

        case .link(let link):
            // Render the link label from its inline children
            var result = renderInlineGroup(link.children)

            // System-handled external link
            if let url = URL(string: link.destination) {
                result.link = url
            }

            // Calm, adaptive styling
            result.foregroundColor = Color.accentColor
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
    // MARK: - Helpers

    func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 24
        case 3: return 20
        default: return 18
        }
    }
}
