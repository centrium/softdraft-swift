import Foundation

struct MarkdownASTParser {
    func parse(_ source: String) -> MarkdownDocument {
        var blockParser = BlockParser(lines: source.normalizedMarkdownLines())
        let blocks = blockParser.parseBlocks()
        return MarkdownDocument(root: .document(blocks: blocks))
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
        guard trimmed == "$$" else { return nil }

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
        return .mathBlock(source: body.joined(separator: "\n"))
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
            return .mathBlock(source: payload)
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

    private mutating func parseList() -> MarkdownBlock? {
        guard let marker = parseListMarker(from: currentLine ?? "") else { return nil }
        var items: [MarkdownListEntry] = []
        var currentLines: [String] = [marker.content]
        let listKind = marker.kind
        let orderedStart = marker.start ?? 1
        index += 1

        func flushCurrent() {
            let text = currentLines.joined(separator: " \n").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else {
                currentLines.removeAll(keepingCapacity: true)
                return
            }

            let taskInfo = parseTaskMarker(from: text)
            let content: String
            if let info = taskInfo {
                content = info.remainder
            } else {
                content = text
            }

            var inlineParser = InlineParser(text: content)
            let inlines = inlineParser.parse()
            let blocks = [MarkdownBlock.paragraph(inlines: inlines)]

            if let info = taskInfo {
                let task = MarkdownTaskListItem(checked: info.checked, blocks: blocks)
                items.append(.taskItem(task))
            } else {
                items.append(.listItem(MarkdownListItem(blocks: blocks)))
            }

            currentLines.removeAll(keepingCapacity: true)
        }

        while !isAtEnd {
            let line = lines[index]
            if line.trimmed().isEmpty {
                currentLines.append("")
                index += 1
                continue
            }
            if let continuation = parseListContinuation(from: line) {
                currentLines.append(continuation)
                index += 1
                continue
            }
            if let nextMarker = parseListMarker(from: line), nextMarker.kind == listKind {
                flushCurrent()
                currentLines.append(nextMarker.content)
                index += 1
                continue
            }
            if startsNewBlock(line) {
                break
            }
            currentLines.append(line.trimmed())
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

        while !isAtEnd {
            let next = lines[index]
            let trimmed = next.trimmed()
            if trimmed.isEmpty {
                index += 1
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
        while idx < line.endIndex && line[idx] == " " {
            idx = line.index(after: idx)
        }
        let remainder = line[idx...].trimmingCharacters(in: .whitespaces)
        return remainder.isEmpty ? nil : remainder
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
        trimmingCharacters(in: .whitespaces)
    }
}

private extension String {
    func normalizedMarkdownLines() -> [String] {
        let normalized = replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let segments = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        if segments.isEmpty {
            return [""]
        }
        return segments.map(String.init)
    }
}

private struct InlineParser {
    let text: String
    private var index: String.Index

    init(text: String) {
        self.text = text
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
        return nodes
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
            var nested = InlineParser(text: label)
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
        var search = index
        while search < text.endIndex {
            if text[search...].hasPrefix(delimiter) {
                return search..<text.index(search, offsetBy: delimiter.count)
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
}
