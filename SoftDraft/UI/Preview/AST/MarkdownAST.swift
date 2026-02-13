import Foundation

struct MarkdownDocument: Equatable {
    let root: MarkdownBlock
}

enum MarkdownBlock: Equatable {
    case document(blocks: [MarkdownBlock])
    case paragraph(inlines: [MarkdownInline])
    case heading(level: Int, inlines: [MarkdownInline])
    case blockQuote(children: [MarkdownBlock])
    case list(style: MarkdownListStyle, items: [MarkdownListEntry])
    case codeBlock(language: String?, source: String)
    case thematicBreak
    case table(MarkdownTable)
    case image(MarkdownImage)
    case mermaidBlock(source: String)
    case mathBlock(source: String)
}

enum MarkdownListStyle: Equatable, Codable {
    case unordered
    case ordered(start: Int)
}

struct MarkdownListItem: Equatable, Codable {
    let blocks: [MarkdownBlock]
}

struct MarkdownTaskListItem: Equatable, Codable {
    let checked: Bool
    let blocks: [MarkdownBlock]
}

enum MarkdownListEntry: Equatable {
    case listItem(MarkdownListItem)
    case taskItem(MarkdownTaskListItem)
}

struct MarkdownTable: Equatable, Codable {
    let alignments: [MarkdownTableAlignment]
    let header: MarkdownTableRow?
    let rows: [MarkdownTableRow]
}

struct MarkdownTableRow: Equatable, Codable {
    let cells: [[MarkdownInline]]
}

enum MarkdownTableAlignment: String, Equatable, Codable {
    case left
    case center
    case right
    case unspecified
}

struct MarkdownImage: Equatable, Codable {
    let source: String
    let alt: String?
}

struct MarkdownLink: Equatable, Codable {
    let destination: String
    let title: String?
    let children: [MarkdownInline]
}

enum MarkdownInline: Equatable {
    case text(String)
    case tag(String)
    case emphasis([MarkdownInline])
    case strong([MarkdownInline])
    case inlineCode(String)
    case link(MarkdownLink)
    case image(MarkdownImage)
    case mathInline(String)
    case highlight([MarkdownInline])
    case strikethrough([MarkdownInline])
}

extension MarkdownListEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case blocks
        case checked
    }

    private enum EntryType: String, Codable {
        case taskItem
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .listItem(let item):
            try container.encode(item.blocks, forKey: .blocks)
        case .taskItem(let task):
            try container.encode(EntryType.taskItem, forKey: .type)
            try container.encode(task.checked, forKey: .checked)
            try container.encode(task.blocks, forKey: .blocks)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(EntryType.self, forKey: .type), type == .taskItem {
            let checked = try container.decode(Bool.self, forKey: .checked)
            let blocks = try container.decode([MarkdownBlock].self, forKey: .blocks)
            self = .taskItem(MarkdownTaskListItem(checked: checked, blocks: blocks))
        } else {
            let blocks = try container.decode([MarkdownBlock].self, forKey: .blocks)
            self = .listItem(MarkdownListItem(blocks: blocks))
        }
    }
}

// MARK: - Codable helpers

extension MarkdownBlock: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case blocks
        case inlines
        case level
        case style
        case start
        case items
        case language
        case source
        case alignments
        case header
        case rows
        case image
    }

    private enum BlockType: String, Codable {
        case document
        case paragraph
        case heading
        case blockQuote
        case list
        case codeBlock
        case thematicBreak
        case table
        case image
        case mermaidBlock
        case mathBlock
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .document(let blocks):
            try container.encode(BlockType.document, forKey: .type)
            try container.encode(blocks, forKey: .blocks)
        case .paragraph(let inlines):
            try container.encode(BlockType.paragraph, forKey: .type)
            try container.encode(inlines, forKey: .inlines)
        case .heading(let level, let inlines):
            try container.encode(BlockType.heading, forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(inlines, forKey: .inlines)
        case .blockQuote(let blocks):
            try container.encode(BlockType.blockQuote, forKey: .type)
            try container.encode(blocks, forKey: .blocks)
        case .list(let style, let items):
            try container.encode(BlockType.list, forKey: .type)
            try container.encode(items, forKey: .items)
            switch style {
            case .unordered:
                try container.encode("unordered", forKey: .style)
            case .ordered(let start):
                try container.encode("ordered", forKey: .style)
                try container.encode(start, forKey: .start)
            }
        case .codeBlock(let language, let source):
            try container.encode(BlockType.codeBlock, forKey: .type)
            try container.encodeIfPresent(language, forKey: .language)
            try container.encode(source, forKey: .source)
        case .thematicBreak:
            try container.encode(BlockType.thematicBreak, forKey: .type)
        case .table(let table):
            try container.encode(BlockType.table, forKey: .type)
            try container.encode(table.alignments, forKey: .alignments)
            try container.encodeIfPresent(table.header, forKey: .header)
            try container.encode(table.rows, forKey: .rows)
        case .image(let image):
            try container.encode(BlockType.image, forKey: .type)
            try container.encode(image, forKey: .image)
        case .mermaidBlock(let source):
            try container.encode(BlockType.mermaidBlock, forKey: .type)
            try container.encode(source, forKey: .source)
        case .mathBlock(let source):
            try container.encode(BlockType.mathBlock, forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BlockType.self, forKey: .type)
        switch type {
        case .document:
            let blocks = try container.decode([MarkdownBlock].self, forKey: .blocks)
            self = .document(blocks: blocks)
        case .paragraph:
            let inlines = try container.decode([MarkdownInline].self, forKey: .inlines)
            self = .paragraph(inlines: inlines)
        case .heading:
            let level = try container.decode(Int.self, forKey: .level)
            let inlines = try container.decode([MarkdownInline].self, forKey: .inlines)
            self = .heading(level: level, inlines: inlines)
        case .blockQuote:
            let blocks = try container.decode([MarkdownBlock].self, forKey: .blocks)
            self = .blockQuote(children: blocks)
        case .list:
            let styleValue = try container.decode(String.self, forKey: .style)
            let items = try container.decode([MarkdownListEntry].self, forKey: .items)
            let style: MarkdownListStyle
            if styleValue == "ordered" {
                let start = try container.decodeIfPresent(Int.self, forKey: .start) ?? 1
                style = .ordered(start: start)
            } else {
                style = .unordered
            }
            self = .list(style: style, items: items)
        case .codeBlock:
            let language = try container.decodeIfPresent(String.self, forKey: .language)
            let source = try container.decode(String.self, forKey: .source)
            self = .codeBlock(language: language, source: source)
        case .thematicBreak:
            self = .thematicBreak
        case .table:
            let alignments = try container.decode([MarkdownTableAlignment].self, forKey: .alignments)
            let header = try container.decodeIfPresent(MarkdownTableRow.self, forKey: .header)
            let rows = try container.decode([MarkdownTableRow].self, forKey: .rows)
            self = .table(MarkdownTable(alignments: alignments, header: header, rows: rows))
        case .image:
            let image = try container.decode(MarkdownImage.self, forKey: .image)
            self = .image(image)
        case .mermaidBlock:
            let source = try container.decode(String.self, forKey: .source)
            self = .mermaidBlock(source: source)
        case .mathBlock:
            let source = try container.decode(String.self, forKey: .source)
            self = .mathBlock(source: source)
        }
    }
}

extension MarkdownDocument: Codable {
    init(from decoder: Decoder) throws {
        root = try MarkdownBlock(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try root.encode(to: encoder)
    }
}

extension MarkdownInline: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case children
        case code
        case linkDestination
        case linkTitle
        case image
        case source
    }

    private enum InlineType: String, Codable {
        case text
        case tag
        case emphasis
        case strong
        case inlineCode
        case link
        case image
        case mathInline
        case highlight
        case strikethrough
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(InlineType.text, forKey: .type)
            try container.encode(text, forKey: .text)
        case .tag(let tag):
            try container.encode(InlineType.tag, forKey: .type)
            try container.encode(tag, forKey: .text)
        case .emphasis(let children):
            try container.encode(InlineType.emphasis, forKey: .type)
            try container.encode(children, forKey: .children)
        case .strong(let children):
            try container.encode(InlineType.strong, forKey: .type)
            try container.encode(children, forKey: .children)
        case .inlineCode(let code):
            try container.encode(InlineType.inlineCode, forKey: .type)
            try container.encode(code, forKey: .code)
        case .link(let link):
            try container.encode(InlineType.link, forKey: .type)
            try container.encode(link.destination, forKey: .linkDestination)
            try container.encodeIfPresent(link.title, forKey: .linkTitle)
            try container.encode(link.children, forKey: .children)
        case .image(let image):
            try container.encode(InlineType.image, forKey: .type)
            try container.encode(image, forKey: .image)
        case .mathInline(let source):
            try container.encode(InlineType.mathInline, forKey: .type)
            try container.encode(source, forKey: .source)
        case .highlight(let children):
            try container.encode(InlineType.highlight, forKey: .type)
            try container.encode(children, forKey: .children)
        case .strikethrough(let children):
            try container.encode(InlineType.strikethrough, forKey: .type)
            try container.encode(children, forKey: .children)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(InlineType.self, forKey: .type)
        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case .tag:
            let tag = try container.decode(String.self, forKey: .text)
            self = .tag(tag)
        case .emphasis:
            let children = try container.decode([MarkdownInline].self, forKey: .children)
            self = .emphasis(children)
        case .strong:
            let children = try container.decode([MarkdownInline].self, forKey: .children)
            self = .strong(children)
        case .inlineCode:
            let code = try container.decode(String.self, forKey: .code)
            self = .inlineCode(code)
        case .link:
            let destination = try container.decode(String.self, forKey: .linkDestination)
            let title = try container.decodeIfPresent(String.self, forKey: .linkTitle)
            let children = try container.decode([MarkdownInline].self, forKey: .children)
            self = .link(MarkdownLink(destination: destination, title: title, children: children))
        case .image:
            let image = try container.decode(MarkdownImage.self, forKey: .image)
            self = .image(image)
        case .mathInline:
            let source = try container.decode(String.self, forKey: .source)
            self = .mathInline(source)
        case .highlight:
            let children = try container.decode([MarkdownInline].self, forKey: .children)
            self = .highlight(children)
        case .strikethrough:
            let children = try container.decode([MarkdownInline].self, forKey: .children)
            self = .strikethrough(children)
        }
    }
}
