import Foundation

struct MarkdownASTParser {
    func parse(_ source: String) -> MarkdownDocument {
        var blockParser = BlockParser(lines: source.normalizedMarkdownLines())
        let blocks = blockParser.parseBlocks()
        let document = MarkdownDocument(root: .document(blocks: blocks))
        return MarkdownInlineTagTransform().apply(to: document)
    }
}

private struct BlockParser {
    var lines: [String]
    var index: Int = 0

    var isAtEnd: Bool {
        index >= lines.count
    }

    mutating func parseBlocks() -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        while true {
            skipBlankLines()
            guard !isAtEnd else { break }
            if let block = parseNextBlock() {
                result.append(block)
            } else {
                index += 1
            }
        }
        return result
    }

    private mutating func parseNextBlock() -> MarkdownBlock? {
        if let math = parseMathBlock() {
            return math
        }
        if let fenced = parseFencedBlock() {
            return fenced
        }
        if let table = parseTable() {
            return table
        }
        if let heading = parseHeading() {
            return heading
        }
        if let hr = parseThematicBreak() {
            return hr
        }
        if let quote = parseBlockQuote() {
            return quote
        }
        if let list = parseList() {
            return list
        }
        return parseParagraph()
    }

    private mutating func parseMathBlock() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        let trimmed = line.trimmed()

        if trimmed == "$$" {
            let startIndex = index
            var cursor = index + 1
            var body: [String] = []
            var closingIndex: Int? = nil

            while cursor < lines.count {
                let candidate = lines[cursor]
                if candidate.trimmed() == "$$" {
                    closingIndex = cursor
                    break
                }
                body.append(candidate)
                cursor += 1
            }

            guard let closing = closingIndex else {
                index = startIndex
                return nil
            }

            index = closing + 1
            let payload = body.joined(separator: "\n")
            return .mathBlock(source: trimmedMathSource(payload))
        }

        if let inlinePayload = singleLineMathContent(from: trimmed) {
            index += 1
            return .mathBlock(source: inlinePayload)
        }

        return nil
    }

    private mutating func parseFencedBlock() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        let trimmed = line.trimmed()
        guard let fence = FenceInfo(line: trimmed) else { return nil }
        index += 1

        var body: [String] = []
        while !isAtEnd {
            let nextLine = lines[index]
            let normalized = nextLine.trimmingCharacters(in: .whitespaces)
            if normalized.hasPrefix(fence.closingPrefix) {
                let suffix = normalized.dropFirst(fence.closingPrefix.count)
                let trimmed = suffix.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.allSatisfy({ $0 == fence.character }) {
                    index += 1
                    break
                }
            }
            body.append(nextLine)
            index += 1
        }

        let payload = body.joined(separator: "\n")
        let info = fence.info.lowercased()
        if info == "mermaid" {
            return .mermaidBlock(source: payload)
        }
        if info == "math" {
            return .mathBlock(source: trimmedMathSource(payload))
        }
        return .codeBlock(language: fence.info.isEmpty ? nil : fence.info, source: payload)
    }

    private mutating func parseTable() -> MarkdownBlock? {
        guard let header = currentLine, let next = peekLine(offset: 1) else { return nil }
        guard header.contains("|") else { return nil }
        guard isAlignmentRow(next) else { return nil }

        let headerCells = parseTableCells(from: header)
        let alignmentTokens = parseTableCells(from: next)
        let alignments = alignmentTokens.map { MarkdownTableAlignment(token: $0) }
        index += 2

        var rows: [MarkdownTableRow] = []
        while !isAtEnd {
            let line = lines[index]
            if line.trimmed().isEmpty { break }
            if !line.contains("|") { break }
            let cells = parseTableCells(from: line)
            let inlineCells = cells.map { cell -> [MarkdownInline] in
                var parser = InlineParser(text: cell)
                return parser.parse()
            }
            rows.append(MarkdownTableRow(cells: inlineCells))
            index += 1
        }

        let headerInlines = headerCells.map { cell -> [MarkdownInline] in
            var parser = InlineParser(text: cell)
            return parser.parse()
        }
        let headerRow = MarkdownTableRow(cells: headerInlines)
        let width = max(headerCells.count, alignments.count)
        let resolvedAlignments: [MarkdownTableAlignment]
        if width == 0 {
            resolvedAlignments = []
        } else if alignments.isEmpty {
            resolvedAlignments = Array(repeating: .unspecified, count: width)
        } else {
            resolvedAlignments = (0..<width).map { position in
                if position < alignments.count {
                    return alignments[position]
                } else {
                    return .unspecified
                }
            }
        }

        return .table(MarkdownTable(alignments: resolvedAlignments, header: headerRow, rows: rows))
    }

    private mutating func parseHeading() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex && line[idx] == "#" && level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0 else { return nil }
        guard idx < line.endIndex && line[idx].isWhitespace else { return nil }
        while idx < line.endIndex && line[idx].isWhitespace {
            idx = line.index(after: idx)
        }
        let content = idx < line.endIndex ? String(line[idx...]) : ""
        index += 1
        var inlineParser = InlineParser(text: content)
        let inlines = inlineParser.parse()
        return .heading(level: level, inlines: inlines)
    }

    private mutating func parseThematicBreak() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        if isThematicBreak(line) {
            index += 1
            return .thematicBreak
        }
        return nil
    }

    private mutating func parseBlockQuote() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        guard line.trimmed().hasPrefix(">") else { return nil }

        var collected: [String] = []
        while !isAtEnd {
            let raw = lines[index]
            let trimmed = raw.trimmed()
            if trimmed.hasPrefix(">") {
                var content = trimmed.dropFirst()
                if content.first == " " { content = content.dropFirst() }
                collected.append(String(content))
                index += 1
                continue
            }
            if trimmed.isEmpty {
                collected.append("")
                index += 1
                continue
            }
            break
        }

        var nested = BlockParser(lines: collected.joined(separator: "\n").normalizedMarkdownLines())
        let blocks = nested.parseBlocks()
        return .blockQuote(children: blocks)
    }

    // Audit 2026-02-04: Parser already recognizes unordered markers (-, *, +) and ordered digits with optional
    // numbering, emitting MarkdownListStyle accordingly. However list items are flattened to a single paragraph
    // and continuation lines drop nested structure, so list item blocks (additional paragraphs, code, nested
    // lists) are not preserved.
    private mutating func parseList() -> MarkdownBlock? {
        guard let marker = parseListMarker(from: currentLine ?? "") else { return nil }
        var items: [MarkdownListEntry] = []
        var currentLines: [String] = [marker.content]
        let listKind = marker.kind
        let orderedStart = marker.start ?? 1
        index += 1
        var encounteredBlankLineAfterItem = false

        func flushCurrent() {
            let raw = currentLines.joined(separator: "\n")
            let trimmedForPresence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedForPresence.isEmpty else {
                currentLines.removeAll(keepingCapacity: true)
                return
            }

            var taskInfo: (checked: Bool, remainder: String)? = nil
            if let first = currentLines.first {
                taskInfo = parseTaskMarker(from: first)
            }

            var linesForParsing = currentLines
            if let info = taskInfo {
                linesForParsing[0] = info.remainder
            }

            let content = linesForParsing.joined(separator: "\n")
            var nestedParser = BlockParser(lines: content.normalizedMarkdownLines())
            let blocks = nestedParser.parseBlocks()
            guard !blocks.isEmpty else {
                currentLines.removeAll(keepingCapacity: true)
                return
            }

            if let info = taskInfo {
                let task = MarkdownTaskListItem(checked: info.checked, blocks: blocks)
                items.append(.taskItem(task))
            } else {
                items.append(.listItem(MarkdownListItem(blocks: blocks)))
            }

            currentLines.removeAll(keepingCapacity: true)
            encounteredBlankLineAfterItem = false
        }

        while !isAtEnd {
            let line = lines[index]
            if line.trimmed().isEmpty {
                currentLines.append("")
                index += 1
                encounteredBlankLineAfterItem = true
                continue
            }
            if let continuation = parseListContinuation(from: line) {
                currentLines.append(continuation)
                index += 1
                encounteredBlankLineAfterItem = false
                continue
            }
            if let nextMarker = parseListMarker(from: line), nextMarker.kind == listKind {
                flushCurrent()
                currentLines.append(nextMarker.content)
                index += 1
                encounteredBlankLineAfterItem = false
                continue
            }
            if startsNewBlock(line) {
                break
            }
            let beginsWithIndent = line.first == " " || line.first == "\t"
            if encounteredBlankLineAfterItem || !beginsWithIndent {
                break
            }
            currentLines.append(line)
            index += 1
        }

        flushCurrent()
        guard !items.isEmpty else { return nil }

        let style: MarkdownListStyle
        switch listKind {
        case .unordered:
            style = .unordered
        case .ordered:
            style = .ordered(start: orderedStart)
        }
        return .list(style: style, items: items)
    }

    private mutating func parseParagraph() -> MarkdownBlock? {
        guard let line = currentLine else { return nil }
        var content: [String] = [line]
        index += 1

        if let image = blockImageIfPresent(in: line) {
            return .image(image)
        }

        let firstLineIsPipe = line.trimmed().hasPrefix("|")
        let shouldIsolatePipeLine: Bool
        if firstLineIsPipe, index < lines.count {
            shouldIsolatePipeLine = lines[index].trimmed().hasPrefix("|")
        } else {
            shouldIsolatePipeLine = false
        }

        while !isAtEnd {
            let next = lines[index]
            let trimmed = next.trimmed()
            if trimmed.isEmpty {
                index += 1
                break
            }
            if shouldIsolatePipeLine {
                break
            }
            if blockImageIfPresent(in: next) != nil {
                break
            }
            if startsNewBlock(next) {
                break
            }
            content.append(next)
            index += 1
        }

        let text = content.joined(separator: " \n")
        var inlineParser = InlineParser(text: text)
        let inlines = inlineParser.parse()
        if inlines.count == 1, case .image(let image) = inlines[0] {
            return .image(image)
        }
        return .paragraph(inlines: inlines)
    }

    private func blockImageIfPresent(in line: String) -> MarkdownImage? {
        let trimmed = line.trimmed()
        guard trimmed.hasPrefix("!["), trimmed.last == ")" else {
            return nil
        }

        var inlineParser = InlineParser(text: trimmed)
        let inlines = inlineParser.parse()
        guard inlines.count == 1, case .image(let image) = inlines[0] else {
            return nil
        }
        return image
    }

    private mutating func skipBlankLines() {
        while !isAtEnd && lines[index].trimmed().isEmpty {
            index += 1
        }
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first else { return false }
        guard first == "-" || first == "*" || first == "_" else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private func startsNewBlock(_ line: String) -> Bool {
        let trimmed = line.trimmed()
        if trimmed.isEmpty { return true }
        if trimmed == "$$" { return true }
        if singleLineMathContent(from: trimmed) != nil { return true }
        if FenceInfo(line: trimmed) != nil { return true }
        if parseListMarker(from: line) != nil { return true }
        if trimmed.hasPrefix(">") { return true }
        if trimmed.hasPrefix("#") {
            var idx = trimmed.startIndex
            var count = 0
            while idx < trimmed.endIndex && trimmed[idx] == "#" && count < 6 {
                count += 1
                idx = trimmed.index(after: idx)
            }
            if idx < trimmed.endIndex && trimmed[idx].isWhitespace { return true }
        }
        if isThematicBreak(trimmed) { return true }
        if trimmed.contains("|") {
            if let second = peekLine(offset: 1) {
                return isAlignmentRow(second)
            }
        }
        return false
    }

    private func parseTaskMarker(from text: String) -> (checked: Bool, remainder: String)? {
        guard text.count >= 3 else { return nil }
        var index = text.startIndex
        guard text[index] == "[" else { return nil }
        index = text.index(after: index)
        guard index < text.endIndex else { return nil }

        let marker = text[index]
        var checked = false

        switch marker {
        case "x", "X":
            checked = true
            index = text.index(after: index)
            guard index < text.endIndex, text[index] == "]" else { return nil }
        case " ":
            index = text.index(after: index)
            guard index < text.endIndex, text[index] == "]" else { return nil }
        case "]":
            // handles []
            break
        default:
            return nil
        }

        index = text.index(after: index)
        guard index < text.endIndex, text[index].isWhitespace else { return nil }

        let remainderStart = text.index(after: index)
        let remainder = String(text[remainderStart...])
        return (checked: checked, remainder: remainder)
    }

    private func parseListMarker(from line: String) -> ListMarker? {
        var working = line
        var indent = 0
        while working.first == " " && indent < 3 {
            working.removeFirst()
            indent += 1
        }
        guard !working.isEmpty else { return nil }

        if working.hasPrefix("- ") || working.hasPrefix("* ") || working.hasPrefix("+ ") {
            let start = working.index(working.startIndex, offsetBy: 2)
            let content = working[start...].trimmingCharacters(in: .whitespaces)
            return ListMarker(kind: .unordered, content: String(content), start: nil)
        }

        var digits = ""
        var idx = working.startIndex
        while idx < working.endIndex && working[idx].isNumber {
            digits.append(working[idx])
            idx = working.index(after: idx)
        }
        guard !digits.isEmpty, idx < working.endIndex else { return nil }
        let delimiter = working[idx]
        guard delimiter == "." || delimiter == ")" else { return nil }
        idx = working.index(after: idx)
        while idx < working.endIndex && working[idx] == " " {
            idx = working.index(after: idx)
        }
        let content = idx < working.endIndex ? String(working[idx...]) : ""
        return ListMarker(kind: .ordered, content: content, start: Int(digits))
    }

    private func parseListContinuation(from line: String) -> String? {
        let trimmed = line.trimmed()
        guard !trimmed.isEmpty else { return nil }
        var spaces = 0
        var idx = line.startIndex
        while idx < line.endIndex && spaces < 2 {
            let char = line[idx]
            if char == " " {
                spaces += 1
                idx = line.index(after: idx)
            } else if char == "\t" {
                spaces = 2
                idx = line.index(after: idx)
                break
            } else {
                break
            }
        }
        guard spaces >= 2 else { return nil }
        let remainder = line[idx...]
        return remainder.isEmpty ? nil : String(remainder)
    }

    private func parseTableCells(from line: String) -> [String] {
        var working = line.trimmed()
        if working.hasPrefix("|") { working.removeFirst() }
        if working.hasSuffix("|") { working.removeLast() }
        return working.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func isAlignmentRow(_ line: String) -> Bool {
        let trimmed = line.trimmed()
        var working = trimmed
        if working.hasPrefix("|") { working.removeFirst() }
        if working.hasSuffix("|") { working.removeLast() }
        let tokens = working.split(separator: "|", omittingEmptySubsequences: false)
        guard !tokens.isEmpty else { return false }

        for token in tokens {
            let value = token.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return false }

            var dashCount = 0
            for char in value {
                if char == "-" {
                    dashCount += 1
                    continue
                }
                if char == ":" {
                    continue
                }
                return false
            }

            guard dashCount >= 3 else { return false }
        }

        return true
    }

    private var currentLine: String? {
        guard index < lines.count else { return nil }
        return lines[index]
    }

    private func peekLine(offset: Int) -> String? {
        let target = index + offset
        guard target >= 0, target < lines.count else { return nil }
        return lines[target]
    }

    private func singleLineMathContent(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("$$") else { return nil }
        let remainder = trimmedLine.dropFirst(2)
        guard remainder.hasSuffix("$$") else { return nil }
        let inner = remainder.dropLast(2)
        return trimmedMathSource(String(inner))
    }

    private func trimmedMathSource(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct FenceInfo {
    let character: Character
    let count: Int
    let info: String

    var closingPrefix: String {
        String(repeating: character, count: count)
    }

    init?(line: String) {
        guard let first = line.first, first == "`" || first == "~" else { return nil }
        character = first
        var idx = line.startIndex
        var total = 0
        while idx < line.endIndex && line[idx] == character {
            total += 1
            idx = line.index(after: idx)
        }
        guard total >= 3 else { return nil }
        count = total
        info = line[idx...].trimmingCharacters(in: .whitespaces)
    }
}

private enum ListKind {
    case unordered
    case ordered
}

private struct ListMarker {
    let kind: ListKind
    let content: String
    let start: Int?
}

private extension MarkdownTableAlignment {
    init(token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        let hasLeft = trimmed.hasPrefix(":")
        let hasRight = trimmed.hasSuffix(":")
        if hasLeft && hasRight {
            self = .center
        } else if hasLeft {
            self = .left
        } else if hasRight {
            self = .right
        } else {
            self = .unspecified
        }
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .markdownWhitespace)
    }
}

private extension CharacterSet {
    static let markdownWhitespace: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        return set
    }()
}

private extension String {
    func normalizedMarkdownLines() -> [String] {
        var normalized = replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

        let unicodeSeparators: [Character] = ["\u{2028}", "\u{2029}", "\u{0085}"]
        for separator in unicodeSeparators {
            normalized = normalized.replacingOccurrences(of: String(separator), with: "\n")
        }

        let segments = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        if segments.isEmpty {
            return [""]
        }
        return segments.map(String.init)
    }
}

private struct InlineParser {
    let text: String
    private let enableAutolinks: Bool
    private var index: String.Index

    init(text: String, enableAutolinks: Bool = true) {
        self.text = text
        self.enableAutolinks = enableAutolinks
        self.index = text.startIndex
    }

    mutating func parse() -> [MarkdownInline] {
        parseSequence(terminator: nil)
    }

    private mutating func parseSequence(terminator: Character?) -> [MarkdownInline] {
        var nodes: [MarkdownInline] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            nodes.append(.text(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            let char = text[index]
            if let terminator, char == terminator {
                break
            }

            if enableAutolinks, let autolink = parseAutolinkIfNeeded(current: char) {
                flushBuffer()
                nodes.append(autolink)
                continue
            }

            switch char {
            case "\\":
                advance()
                if index < text.endIndex {
                    buffer.append(text[index])
                    advance()
                }
            case "`":
                flushBuffer()
                if let code = parseInlineCode() {
                    nodes.append(.inlineCode(code))
                } else {
                    buffer.append("`")
                    advance()
                }
            case "$":
                flushBuffer()
                if let math = parseMath() {
                    nodes.append(.mathInline(math))
                } else {
                    buffer.append("$")
                    advance()
                }
            case "!":
                if peekNext() == "[" {
                    flushBuffer()
                    advance() // consume !
                    if let imageNode = parseLinkOrImage(expectImage: true) {
                        nodes.append(imageNode)
                    } else {
                        buffer.append("!")
                    }
                } else {
                    buffer.append(char)
                    advance()
                }
            case "[":
                flushBuffer()
                if let link = parseLinkOrImage(expectImage: false) {
                    nodes.append(link)
                } else {
                    buffer.append("[")
                    advance()
                }
            case "*", "_":
                flushBuffer()
                if let emphasis = parseEmphasis(delimiter: char) {
                    nodes.append(emphasis)
                } else {
                    buffer.append(char)
                    advance()
                }
            case "~":
                if peekNext() == "~" {
                    flushBuffer()
                    if let strike = parseStrikethrough() {
                        nodes.append(strike)
                    } else {
                        buffer.append("~")
                        advance()
                    }
                } else {
                    buffer.append("~")
                    advance()
                }
            case "=":
                if peekNext() == "=" {
                    flushBuffer()
                    if let highlight = parseHighlight() {
                        nodes.append(highlight)
                    } else {
                        buffer.append("=")
                        advance()
                    }
                } else {
                    buffer.append("=")
                    advance()
                }
            default:
                buffer.append(char)
                advance()
            }
        }

        flushBuffer()
        return mergeAdjacentText(nodes)
    }

    private mutating func parseInlineCode() -> String? {
        let start = index
        let count = consumeRepeated("`")
        guard count > 0 else { return nil }
        let closing = String(repeating: "`", count: count)
        guard let closingRange = findClosing(delimiter: closing) else {
            index = start
            return nil
        }
        let content = String(text[index..<closingRange.lowerBound])
        index = closingRange.upperBound
        return content
    }

    private mutating func parseMath() -> String? {
        let start = index
        guard consume("$") else { return nil }

        let delimiter: String
        if index < text.endIndex, text[index] == "$" {
            advance()
            delimiter = "$$"
        } else {
            delimiter = "$"
        }

        guard let closingRange = findClosing(delimiter: delimiter) else {
            index = start
            return nil
        }

        let content = String(text[index..<closingRange.lowerBound])
        index = closingRange.upperBound
        return content
    }

    private mutating func parseHighlight() -> MarkdownInline? {
        let start = index
        guard consume("==") else { return nil }
        guard let closingRange = findClosing(delimiter: "==") else {
            index = start
            return nil
        }

        let content = String(text[index..<closingRange.lowerBound])
        guard !content.isEmpty else {
            index = start
            return nil
        }

        var nested = InlineParser(text: content)
        let children = nested.parse()
        guard !children.isEmpty else {
            index = start
            return nil
        }

        index = closingRange.upperBound
        return .highlight(children)
    }

    private mutating func parseStrikethrough() -> MarkdownInline? {
        let start = index
        guard consume("~~") else { return nil }
        guard let closing = findClosing(delimiter: "~~") else {
            index = start
            return nil
        }
        let content = String(text[index..<closing.lowerBound])
        guard !content.isEmpty else {
            index = start
            return nil
        }
        var nested = InlineParser(text: content)
        let children = nested.parse()
        index = closing.upperBound
        return .strikethrough(children)
    }

    private mutating func parseEmphasis(delimiter: Character) -> MarkdownInline? {
        let start = index
        if let strong = parseDelimited(String(repeating: delimiter, count: 2), builder: MarkdownInline.strong) {
            return strong
        }
        index = start
        if let emphasis = parseDelimited(String(delimiter), builder: MarkdownInline.emphasis) {
            return emphasis
        }
        index = start
        return nil
    }

    private mutating func parseDelimited(
        _ delimiter: String,
        builder: ([MarkdownInline]) -> MarkdownInline
    ) -> MarkdownInline? {
        guard consume(delimiter) else { return nil }
        guard let closing = findClosing(delimiter: delimiter) else { return nil }
        let content = String(text[index..<closing.lowerBound])
        var nested = InlineParser(text: content)
        let children = nested.parse()
        index = closing.upperBound
        return builder(children)
    }

    private mutating func parseLinkOrImage(expectImage: Bool) -> MarkdownInline? {
        let start = index
        guard consume("[") else { index = start; return nil }
        guard let label = readBracketedText() else { index = start; return nil }
        guard consume("]") else { index = start; return nil }
        guard consume("(") else { index = start; return nil }
        skipWhitespace()
        guard let destination = readLinkDestination() else { index = start; return nil }
        skipWhitespace()
        let title = readLinkTitle()
        skipWhitespace()
        guard consume(")") else { index = start; return nil }

        if expectImage {
            let alt = label.isEmpty ? nil : label
            return .image(MarkdownImage(source: destination, alt: alt))
        } else {
            var nested = InlineParser(text: label, enableAutolinks: false)
            let children = nested.parse()
            return .link(MarkdownLink(destination: destination, title: title, children: children))
        }
    }

    private mutating func readBracketedText() -> String? {
        var depth = 1
        let start = index
        while index < text.endIndex {
            let char = text[index]
            if char == "\\" {
                advance()
                if index < text.endIndex { advance() }
                continue
            }
            if char == "[" {
                depth += 1
            } else if char == "]" {
                depth -= 1
                if depth == 0 {
                    let value = String(text[start..<index])
                    return value
                }
            }
            advance()
        }
        return nil
    }

    private mutating func readLinkDestination() -> String? {
        var buffer = ""
        while index < text.endIndex {
            let char = text[index]
            if char == "\\" {
                advance()
                if index < text.endIndex {
                    buffer.append(text[index])
                    advance()
                }
                continue
            }
            if char == ")" {
                return buffer.isEmpty ? nil : buffer
            }
            if char.isWhitespace {
                return buffer.isEmpty ? nil : buffer
            }
            buffer.append(char)
            advance()
        }
        return buffer.isEmpty ? nil : buffer
    }

    private mutating func readLinkTitle() -> String? {
        guard index < text.endIndex else { return nil }
        let char = text[index]
        guard char == "\"" || char == "'" else { return nil }
        advance()
        var buffer = ""
        while index < text.endIndex {
            let current = text[index]
            if current == char {
                advance()
                return buffer.isEmpty ? nil : buffer
            }
            buffer.append(current)
            advance()
        }
        return nil
    }

    private mutating func consumeRepeated(_ character: Character) -> Int {
        var count = 0
        while index < text.endIndex && text[index] == character {
            count += 1
            advance()
        }
        return count
    }

    private mutating func consume(_ token: String) -> Bool {
        guard index < text.endIndex else { return false }
        if text[index...].hasPrefix(token) {
            index = text.index(index, offsetBy: token.count)
            return true
        }
        return false
    }

    private mutating func findClosing(delimiter: String) -> Range<String.Index>? {
        guard let first = delimiter.first else { return nil }
        let length = delimiter.count
        var search = index

        func advancePastRun(from start: String.Index) -> String.Index {
            var cursor = start
            while cursor < text.endIndex && text[cursor] == first {
                cursor = text.index(after: cursor)
            }
            return cursor
        }

        while search < text.endIndex {
            if text[search] == first {
                var cursor = search
                var matched = 0
                while cursor < text.endIndex && text[cursor] == first && matched < length {
                    matched += 1
                    cursor = text.index(after: cursor)
                }

                if matched == length {
                    if length == 1 {
                        let runEnd = advancePastRun(from: search)
                        if runEnd > cursor {
                            search = runEnd
                            continue
                        }
                    }
                    return search..<cursor
                }

                search = advancePastRun(from: search)
                continue
            }

            if text[search] == "\\" {
                search = text.index(after: search)
                if search < text.endIndex {
                    search = text.index(after: search)
                }
                continue
            }

            search = text.index(after: search)
        }
        return nil
    }

    private mutating func skipWhitespace() {
        while index < text.endIndex && text[index].isWhitespace {
            advance()
        }
    }

    private func peekNext() -> Character? {
        guard index < text.endIndex else { return nil }
        let next = text.index(after: index)
        guard next < text.endIndex else { return nil }
        return text[next]
    }

    private mutating func advance() {
        guard index < text.endIndex else { return }
        index = text.index(after: index)
    }

    private func mergeAdjacentText(_ nodes: [MarkdownInline]) -> [MarkdownInline] {
        guard !nodes.isEmpty else { return nodes }
        var merged: [MarkdownInline] = []
        merged.reserveCapacity(nodes.count)

        for node in nodes {
            if case .text(let value) = node,
               case .text(let existing)? = merged.last {
                merged[merged.count - 1] = .text(existing + value)
            } else {
                merged.append(node)
            }
        }

        return merged
    }

    private mutating func parseAutolinkIfNeeded(current: Character) -> MarkdownInline? {
        guard current == "h" else { return nil }
        guard let prefixLength = InlineParser.autolinkPrefixLength(at: index, in: text) else { return nil }
        guard InlineParser.isAutolinkBoundary(before: index, in: text) else { return nil }

        var end = text.index(index, offsetBy: prefixLength)
        while end < text.endIndex {
            let char = text[end]
            if char.isWhitespace || char.isNewline || InlineParser.hardStopCharacters.contains(char) {
                break
            }
            end = text.index(after: end)
        }

        let candidate = index..<end
        guard let trimmed = InlineParser.trimTrailingPunctuation(in: text, range: candidate) else {
            return nil
        }

        let url = String(text[trimmed])
        guard !url.isEmpty else { return nil }

        index = trimmed.upperBound
        let link = MarkdownLink(destination: url, title: nil, children: [.text(url)])
        return .link(link)
    }

    private static func autolinkPrefixLength(at index: String.Index, in text: String) -> Int? {
        for prefix in autolinkPrefixes {
            if text[index...].hasPrefix(prefix) {
                return prefix.count
            }
        }
        return nil
    }

    private static func isAutolinkBoundary(before index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        if previous.isLetter || previous.isNumber || previous == "_" || previous == "/" {
            return false
        }
        return true
    }

    private static func trimTrailingPunctuation(in text: String, range: Range<String.Index>) -> Range<String.Index>? {
        var end = range.upperBound
        let start = range.lowerBound

        while end > start {
            let previousIndex = text.index(before: end)
            let character = text[previousIndex]
            if trailingDelimiters.contains(character) {
                if character == ")" {
                    let segment = text[start..<previousIndex]
                    if segment.contains("(") {
                        break
                    }
                }
                end = previousIndex
                continue
            }
            break
        }

        return start < end ? start..<end : nil
    }

    private static let autolinkPrefixes = ["http://", "https://"]
    private static let hardStopCharacters: Set<Character> = ["<", ">", "\"", "'"]
    private static let trailingDelimiters: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}"]
}
