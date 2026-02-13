import Foundation

struct MarkdownInlineTagTransform {
    func apply(to document: MarkdownDocument) -> MarkdownDocument {
        MarkdownDocument(root: transformBlock(document.root))
    }

    private func transformBlock(_ block: MarkdownBlock) -> MarkdownBlock {
        switch block {
        case .document(let blocks):
            return .document(blocks: blocks.map(transformBlock))
        case .paragraph(let inlines):
            return .paragraph(inlines: transformInlines(inlines))
        case .heading(let level, let inlines):
            return .heading(level: level, inlines: transformInlines(inlines))
        case .blockQuote(let children):
            return .blockQuote(children: children.map(transformBlock))
        case .list(let style, let items):
            return .list(style: style, items: items.map(transformListEntry))
        case .table(let table):
            return .table(transformTable(table))
        case .codeBlock,
             .thematicBreak,
             .image,
             .mermaidBlock,
             .mathBlock:
            return block
        }
    }

    private func transformListEntry(_ entry: MarkdownListEntry) -> MarkdownListEntry {
        switch entry {
        case .listItem(let item):
            return .listItem(MarkdownListItem(blocks: item.blocks.map(transformBlock)))
        case .taskItem(let task):
            return .taskItem(MarkdownTaskListItem(checked: task.checked, blocks: task.blocks.map(transformBlock)))
        }
    }

    private func transformTable(_ table: MarkdownTable) -> MarkdownTable {
        let header = table.header.map(transformTableRow)
        let rows = table.rows.map(transformTableRow)
        return MarkdownTable(alignments: table.alignments, header: header, rows: rows)
    }

    private func transformTableRow(_ row: MarkdownTableRow) -> MarkdownTableRow {
        MarkdownTableRow(cells: row.cells.map(transformInlines))
    }

    private func transformInlines(_ inlines: [MarkdownInline]) -> [MarkdownInline] {
        var transformed: [MarkdownInline] = []
        transformed.reserveCapacity(inlines.count)

        for inline in inlines {
            switch inline {
            case .text(let value):
                transformed.append(contentsOf: transformText(value))
            case .emphasis(let children):
                transformed.append(.emphasis(transformInlines(children)))
            case .strong(let children):
                transformed.append(.strong(transformInlines(children)))
            case .highlight(let children):
                transformed.append(.highlight(transformInlines(children)))
            case .strikethrough(let children):
                transformed.append(.strikethrough(transformInlines(children)))
            case .tag,
                 .inlineCode,
                 .mathInline,
                 .link,
                 .image:
                transformed.append(inline)
            }
        }

        return mergeAdjacentTextNodes(in: transformed)
    }

    private func transformText(_ text: String) -> [MarkdownInline] {
        guard !text.isEmpty else { return [] }

        var parts: [MarkdownInline] = []
        var segmentStart = text.startIndex
        var cursor = text.startIndex

        while cursor < text.endIndex {
            guard text[cursor] == "#",
                  isValidTagStart(in: text, at: cursor)
            else {
                cursor = text.index(after: cursor)
                continue
            }

            let tagStart = text.index(after: cursor)
            var tagEnd = tagStart
            while tagEnd < text.endIndex && isValidTagBodyCharacter(text[tagEnd]) {
                tagEnd = text.index(after: tagEnd)
            }

            guard tagStart < tagEnd else {
                cursor = text.index(after: cursor)
                continue
            }

            let lastTagCharacter = text[text.index(before: tagEnd)]
            guard isValidTagTerminator(in: text, at: tagEnd, lastTagCharacter: lastTagCharacter) else {
                cursor = text.index(after: cursor)
                continue
            }

            if segmentStart < cursor {
                parts.append(.text(String(text[segmentStart..<cursor])))
            }
            parts.append(.tag(String(text[tagStart..<tagEnd])))
            segmentStart = tagEnd
            cursor = tagEnd
        }

        if segmentStart < text.endIndex {
            parts.append(.text(String(text[segmentStart...])))
        }

        return parts.isEmpty ? [.text(text)] : parts
    }

    private func isValidTagStart(in text: String, at hashIndex: String.Index) -> Bool {
        if hashIndex > text.startIndex {
            let previous = text[text.index(before: hashIndex)]
            if isWordCharacter(previous) {
                return false
            }
        }

        let next = text.index(after: hashIndex)
        guard next < text.endIndex else { return false }
        return isASCIILetter(text[next])
    }

    private func isValidTagBodyCharacter(_ character: Character) -> Bool {
        isASCIILetter(character) || character.isNumber || character == "_" || character == "-"
    }

    private func isValidTagTerminator(
        in text: String,
        at index: String.Index,
        lastTagCharacter: Character
    ) -> Bool {
        guard index < text.endIndex else { return true }
        let next = text[index]

        if next.isWhitespace {
            return true
        }
        if terminatingPunctuation.contains(next) {
            return true
        }

        let lastIsWord = isWordCharacter(lastTagCharacter)
        let nextIsWord = isWordCharacter(next)
        return lastIsWord != nextIsWord
    }

    private func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1
        else {
            return false
        }
        return (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func mergeAdjacentTextNodes(in inlines: [MarkdownInline]) -> [MarkdownInline] {
        guard !inlines.isEmpty else { return inlines }

        var merged: [MarkdownInline] = []
        merged.reserveCapacity(inlines.count)

        for inline in inlines {
            if case .text(let value) = inline,
               case .text(let existing)? = merged.last {
                merged[merged.count - 1] = .text(existing + value)
            } else {
                merged.append(inline)
            }
        }

        return merged
    }

    private let terminatingPunctuation: Set<Character> = [".", ",", "!", "?", ")", "]"]
}
