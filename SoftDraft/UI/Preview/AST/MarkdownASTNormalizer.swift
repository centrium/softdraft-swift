import Foundation

struct MarkdownASTNormalizer {
    func normalize(_ document: MarkdownDocument) -> MarkdownDocument {
        MarkdownDocument(root: normalizeBlock(document.root))
    }

    private func normalizeBlock(_ block: MarkdownBlock) -> MarkdownBlock {
        switch block {
        case .document(let blocks):
            return .document(blocks: blocks.map(normalizeBlock))
        case .blockQuote(let children):
            return .blockQuote(children: children.map(normalizeBlock))
        case .list(let style, let items):
            return .list(style: style, items: items.map(normalizeListEntry))
        case .paragraph(let inlines):
            if inlines.count == 1, case .image(let image) = inlines[0] {
                return .image(image)
            }
            return .paragraph(inlines: inlines)
        case .heading,
             .codeBlock,
             .thematicBreak,
             .table,
             .image,
             .mermaidBlock,
             .mathBlock:
            return block
        }
    }

    private func normalizeListEntry(_ entry: MarkdownListEntry) -> MarkdownListEntry {
        switch entry {
        case .listItem(let item):
            let blocks = item.blocks.map(normalizeBlock)
            return .listItem(MarkdownListItem(blocks: blocks))
        case .taskItem(let task):
            let blocks = task.blocks.map(normalizeBlock)
            return .taskItem(MarkdownTaskListItem(checked: task.checked, blocks: blocks))
        }
    }
}
