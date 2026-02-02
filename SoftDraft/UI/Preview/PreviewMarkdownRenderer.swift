import Foundation

struct PreviewMarkdownRenderer {

    private let inlineProcessor = InlineProcessor()

    func render(_ markdown: String) -> String {
        var builder = HTMLBuilder(inlineProcessor: inlineProcessor)
        return builder.makeHTML(from: markdown)
    }
}

private struct HTMLBuilder {

    let inlineProcessor: InlineProcessor

    private var htmlParts: [String] = []
    private var paragraphLines: [String] = []
    private var blockquoteLines: [String]? = nil
    private var listState: ListAccumulator? = nil
    private var codeBlock: CodeBlockAccumulator? = nil

    init(inlineProcessor: InlineProcessor) {
        self.inlineProcessor = inlineProcessor
    }

    mutating func makeHTML(from markdown: String) -> String {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let segments = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let lines = segments.isEmpty ? [""] : segments.map(String.init)

        for line in lines {
            process(line: line)
        }

        flushParagraph()
        flushList()
        flushBlockquote()
        flushCodeBlock()

        return htmlParts.joined(separator: "\n")
    }

    private mutating func process(line: String) {
        let trimmedForFence = line.trimmingCharacters(in: .whitespaces)

        if trimmedForFence.hasPrefix("```") {
            handleFence(delimiter: trimmedForFence)
            return
        }

        if let current = codeBlock, current.isFenced {
            appendToCurrentCodeBlock(line)
            return
        }

        if handleIndentedCode(line: line) {
            return
        }

        let trimmed = trimmedForFence

        if trimmed.isEmpty {
            flushParagraph()
            flushList()
            flushBlockquote()
            return
        }

        if trimmed.hasPrefix(">") {
            flushParagraph()
            flushList()
            appendBlockquoteLine(trimmed)
            return
        } else if blockquoteLines != nil {
            flushBlockquote()
        }

        if handleHeading(line: trimmed) {
            return
        }

        if handleHorizontalRule(line: trimmed) {
            return
        }

        if listState != nil, let continuation = parseListContinuation(from: line) {
            extendCurrentList(with: continuation)
            return
        }

        if handleList(line: trimmed) {
            return
        }

        flushList()
        paragraphLines.append(trimmed)
    }

    // MARK: - Block helpers

    private mutating func handleFence(delimiter: String) {
        if let state = codeBlock, state.isFenced {
            flushCodeBlock()
        } else {
            flushParagraph()
            flushList()
            flushBlockquote()

            let fence = delimiter.drop { $0 == "`" }
            let language = fence.trimmingCharacters(in: .whitespaces)
            let tag = language.isEmpty ? nil : language
            codeBlock = CodeBlockAccumulator(language: tag, lines: [], isFenced: true)
        }
    }

    private mutating func handleIndentedCode(line: String) -> Bool {
        if var state = codeBlock, !state.isFenced {
            let info = indentationInfo(for: line, limit: 4)
            if info.count >= 4 {
                let content = String(line[info.index...])
                state.lines.append(content)
                codeBlock = state
                return true
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                state.lines.append("")
                codeBlock = state
                return true
            }

            codeBlock = state
            flushCodeBlock()
        }

        let info = indentationInfo(for: line, limit: 4)
        guard info.count >= 4 else { return false }

        flushParagraph()
        flushList()
        flushBlockquote()

        let content = String(line[info.index...])
        codeBlock = CodeBlockAccumulator(language: nil, lines: [content], isFenced: false)
        return true
    }

    private func indentationInfo(for line: String, limit: Int) -> (count: Int, index: String.Index) {
        var count = 0
        var index = line.startIndex

        while index < line.endIndex, count < limit {
            let char = line[index]
            if char == " " {
                count += 1
                index = line.index(after: index)
            } else if char == "\t" {
                count = limit
                index = line.index(after: index)
                break
            } else {
                break
            }
        }

        return (count, index)
    }

    private mutating func appendToCurrentCodeBlock(_ line: String) {
        guard var state = codeBlock else { return }
        state.lines.append(line)
        codeBlock = state
    }

    private mutating func flushCodeBlock() {
        guard let state = codeBlock else { return }
        let body = state.lines.joined(separator: "\n")
        let escaped = htmlEscape(body)

        if let language = state.language, !language.isEmpty {
            htmlParts.append("<pre><code class=\"language-\(attributeEscape(language))\">\(escaped)\n</code></pre>")
        } else {
            htmlParts.append("<pre><code>\(escaped)\n</code></pre>")
        }

        codeBlock = nil
    }

    private mutating func flushParagraph() {
        guard !paragraphLines.isEmpty else { return }
        let collapsed = paragraphLines.joined(separator: " ")
        htmlParts.append("<p>\(inlineProcessor.render(collapsed))</p>")
        paragraphLines.removeAll(keepingCapacity: true)
    }

    private mutating func appendBlockquoteLine(_ line: String) {
        var contentIndex = line.index(after: line.startIndex)
        while contentIndex < line.endIndex, line[contentIndex].isWhitespace {
            contentIndex = line.index(after: contentIndex)
        }
        let content = contentIndex < line.endIndex ? String(line[contentIndex...]) : ""

        if blockquoteLines == nil {
            blockquoteLines = []
        }
        blockquoteLines?.append(content)
    }

    private mutating func flushBlockquote() {
        guard let lines = blockquoteLines else { return }

        var paragraphs: [String] = []
        var buffer: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !buffer.isEmpty {
                    let joined = buffer.joined(separator: " ")
                    paragraphs.append(inlineProcessor.render(joined))
                    buffer.removeAll(keepingCapacity: true)
                }
            } else {
                buffer.append(line)
            }
        }

        if !buffer.isEmpty {
            let joined = buffer.joined(separator: " ")
            paragraphs.append(inlineProcessor.render(joined))
        }

        if paragraphs.isEmpty {
            paragraphs.append("")
        }

        let body = paragraphs.map { "<p>\($0)</p>" }.joined()
        htmlParts.append("<blockquote>\(body)</blockquote>")

        blockquoteLines = nil
    }

    private mutating func handleHeading(line: String) -> Bool {
        guard let heading = parseHeading(from: line) else { return false }

        flushParagraph()
        flushList()

        htmlParts.append("<h\(heading.level)>\(inlineProcessor.render(heading.text))</h\(heading.level)>")
        return true
    }

    private func parseHeading(from line: String) -> (level: Int, text: String)? {
        guard line.first == "#" else { return nil }

        var level = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", level < 6 {
            level += 1
            index = line.index(after: index)
        }

        guard level > 0 else { return nil }
        guard index < line.endIndex, line[index].isWhitespace else { return nil }

        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }

        let text = index < line.endIndex ? String(line[index...]) : ""
        return (level, text)
    }

    private mutating func handleHorizontalRule(line: String) -> Bool {
        guard isHorizontalRule(line) else { return false }

        flushParagraph()
        flushList()
        htmlParts.append("<hr />")
        return true
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first else { return false }
        guard first == "-" || first == "*" || first == "_" else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private mutating func handleList(line: String) -> Bool {
        guard let marker = parseListMarker(from: line) else { return false }

        flushBlockquote()

        if let current = listState, current.kind != marker.kind {
            flushList()
        }

        var state = listState ?? ListAccumulator(kind: marker.kind, start: marker.start)
        if state.kind == .ordered, state.start == nil {
            state.start = marker.start ?? 1
        }
        state.items.append(marker.content)
        listState = state
        return true
    }

    private mutating func extendCurrentList(with continuation: String) {
        guard var state = listState, !state.items.isEmpty else { return }
        state.items[state.items.count - 1] += " " + continuation
        listState = state
    }

    private func parseListMarker(from line: String) -> ListMarker? {
        var working = line
        var indentCount = 0
        while working.first == " ", indentCount < 3 {
            working.removeFirst()
            indentCount += 1
        }

        guard !working.isEmpty else { return nil }

        if working.hasPrefix("- ") || working.hasPrefix("* ") || working.hasPrefix("+ ") {
            let start = working.index(working.startIndex, offsetBy: 2)
            let content = working[start...].trimmingCharacters(in: .whitespaces)
            return ListMarker(kind: .unordered, content: String(content), start: nil)
        }

        var index = working.startIndex
        var digits = ""
        while index < working.endIndex, working[index].isNumber {
            digits.append(working[index])
            index = working.index(after: index)
        }

        guard !digits.isEmpty, index < working.endIndex else { return nil }

        let delimiter = working[index]
        guard delimiter == "." || delimiter == ")" else { return nil }

        index = working.index(after: index)
        while index < working.endIndex, working[index] == " " {
            index = working.index(after: index)
        }

        let content = index < working.endIndex ? String(working[index...]) : ""
        return ListMarker(kind: .ordered, content: content, start: Int(digits))
    }

    private func parseListContinuation(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var spaces = 0
        var index = line.startIndex
        while index < line.endIndex, spaces < 2 {
            let char = line[index]
            if char == " " {
                spaces += 1
                index = line.index(after: index)
            } else if char == "\t" {
                spaces = 2
                index = line.index(after: index)
                break
            } else {
                break
            }
        }

        guard spaces >= 2 else { return nil }

        while index < line.endIndex, line[index] == " " {
            index = line.index(after: index)
        }

        let remainder = line[index...].trimmingCharacters(in: .whitespaces)
        return remainder.isEmpty ? nil : remainder
    }

    private mutating func flushList() {
        guard let state = listState, !state.items.isEmpty else {
            listState = nil
            return
        }

        let listHTML: String
        switch state.kind {
        case .unordered:
            listHTML = "<ul>\(state.items.map { "<li>\(inlineProcessor.render($0))</li>" }.joined())</ul>"
        case .ordered:
            if let start = state.start, start > 1 {
                listHTML = "<ol start=\"\(start)\">\(state.items.map { "<li>\(inlineProcessor.render($0))</li>" }.joined())</ol>"
            } else {
                listHTML = "<ol>\(state.items.map { "<li>\(inlineProcessor.render($0))</li>" }.joined())</ol>"
            }
        }

        htmlParts.append(listHTML)
        listState = nil
    }
}

private struct ListAccumulator {
    enum Kind {
        case unordered
        case ordered
    }

    var kind: Kind
    var start: Int?
    var items: [String] = []
}

private struct ListMarker {
    var kind: ListAccumulator.Kind
    var content: String
    var start: Int?
}

private struct CodeBlockAccumulator {
    var language: String?
    var lines: [String]
    var isFenced: Bool
}

// MARK: - Inline processing

private struct InlineProcessor {

    private static let codeRegex = try! NSRegularExpression(
        pattern: "(?<!`)(`{1,3})([^`]+?)\\1(?!`)",
        options: []
    )

    private static let imageRegex = try! NSRegularExpression(
        pattern: "!\\[([^\\]]*)\\]\\(([^)\\s]+)(?:\\s+\\\"([^\\\"]+)\\\")?\\)",
        options: []
    )

    private static let linkRegex = try! NSRegularExpression(
        pattern: "(?<!!)\\[([^\\]]+)\\]\\(([^)\\s]+)(?:\\s+\\\"([^\\\"]+)\\\")?\\)",
        options: []
    )

    private static let strongRegex = try! NSRegularExpression(
        pattern: "(\\*\\*|__)(?=\\S)([\\s\\S]+?)(?<=\\S)\\1",
        options: []
    )

    private static let emphasisRegex = try! NSRegularExpression(
        pattern: "(?<!\\*)\\*(?!\\*)(?=\\S)([^\\*]+?)(?<=\\S)\\*(?!\\*)|(?<!_)_(?!_)(?=\\S)([^_]+?)(?<=\\S)_(?!_)",
        options: []
    )

    private static let strikeRegex = try! NSRegularExpression(
        pattern: "~~(?=\\S)(.+?)(?<=\\S)~~",
        options: []
    )

    private static let anchorTagRegex = try! NSRegularExpression(
        pattern: "<a\\b[^>]*>.*?<\\/a>",
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    private static let imageTagRegex = try! NSRegularExpression(
        pattern: "<img\\b[^>]*?>",
        options: [.caseInsensitive]
    )

    private static let autoLinkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    func render(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var output = htmlEscape(text)
        var placeholders = PlaceholderStore()

        output = replace(output, with: Self.codeRegex) { match, value -> String in
            guard match.numberOfRanges > 2,
                  let range = Range(match.range(at: 2), in: value)
            else { return "" }

            let code = String(value[range])
            return placeholders.insert("<code>\(code)</code>")
        }

        output = replace(output, with: Self.imageRegex) { match, value -> String in
            guard match.numberOfRanges >= 3,
                  let altRange = Range(match.range(at: 1), in: value),
                  let urlRange = Range(match.range(at: 2), in: value)
            else { return "" }

            let alt = String(value[altRange])
            let url = String(value[urlRange])
            let title: String?
            if match.numberOfRanges > 3, let titleRange = Range(match.range(at: 3), in: value) {
                let raw = String(value[titleRange])
                title = raw.isEmpty ? nil : raw
            } else {
                title = nil
            }

            var attributes = "src=\"\(attributeEscape(url))\" alt=\"\(attributeEscape(alt))\""
            if let title {
                attributes += " title=\"\(attributeEscape(title))\""
            }

            return "<img \(attributes) />"
        }

        output = replace(output, with: Self.linkRegex) { match, value -> String in
            guard match.numberOfRanges >= 3,
                  let textRange = Range(match.range(at: 1), in: value),
                  let urlRange = Range(match.range(at: 2), in: value)
            else { return "" }

            let label = String(value[textRange])
            let url = String(value[urlRange])
            let title: String?
            if match.numberOfRanges > 3, let titleRange = Range(match.range(at: 3), in: value) {
                let raw = String(value[titleRange])
                title = raw.isEmpty ? nil : raw
            } else {
                title = nil
            }

            var attributes = "href=\"\(attributeEscape(url))\""
            if let title {
                attributes += " title=\"\(attributeEscape(title))\""
            }

            return "<a \(attributes)>\(label)</a>"
        }

        output = replace(output, with: Self.strongRegex) { match, value -> String in
            guard match.numberOfRanges > 2,
                  let range = Range(match.range(at: 2), in: value)
            else { return "" }
            let inner = String(value[range])
            return "<strong>\(inner)</strong>"
        }

        output = replace(output, with: Self.emphasisRegex) { match, value -> String in
            let groupIndex = match.range(at: 1).location != NSNotFound ? 1 : 2
            guard groupIndex < match.numberOfRanges,
                  let range = Range(match.range(at: groupIndex), in: value)
            else { return "" }
            let inner = String(value[range])
            return "<em>\(inner)</em>"
        }

        output = replace(output, with: Self.strikeRegex) { match, value -> String in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: value)
            else { return "" }
            let inner = String(value[range])
            return "<s>\(inner)</s>"
        }

        output = protectHTMLFragments(output, placeholders: &placeholders)
        output = autoLink(output, placeholders: &placeholders)

        return placeholders.resolve(in: output)
    }

    private func replace(
        _ text: String,
        with regex: NSRegularExpression,
        transformer: (NSTextCheckingResult, String) -> String
    ) -> String {
        var mutable = text
        let matches = regex.matches(in: mutable, options: [], range: NSRange(location: 0, length: mutable.utf16.count))
        guard !matches.isEmpty else { return mutable }

        for match in matches.reversed() {
            guard let range = Range(match.range, in: mutable) else { continue }
            let replacement = transformer(match, mutable)
            mutable.replaceSubrange(range, with: replacement)
        }

        return mutable
    }

    private func protectHTMLFragments(
        _ text: String,
        placeholders: inout PlaceholderStore
    ) -> String {
        var mutable = text

        let regexes = [Self.anchorTagRegex, Self.imageTagRegex]
        for regex in regexes {
            let searchRange = NSRange(location: 0, length: mutable.utf16.count)
            let matches = regex.matches(in: mutable, options: [], range: searchRange)
            for match in matches.reversed() {
                guard let range = Range(match.range, in: mutable) else { continue }
                let fragment = String(mutable[range])
                let token = placeholders.insert(fragment)
                mutable.replaceSubrange(range, with: token)
            }
        }

        return mutable
    }

    private func autoLink(
        _ text: String,
        placeholders: inout PlaceholderStore
    ) -> String {
        guard let detector = Self.autoLinkDetector else { return text }

        var mutable = text
        let nsRange = NSRange(location: 0, length: mutable.utf16.count)
        let matches = detector.matches(in: mutable, options: [], range: nsRange)
        guard !matches.isEmpty else { return mutable }

        for match in matches.reversed() {
            guard
                let url = match.url,
                let range = Range(match.range, in: mutable)
            else { continue }

            let display = String(mutable[range])
            let html = "<a href=\"\(attributeEscape(url.absoluteString))\">\(display)</a>"
            let token = placeholders.insert(html)
            mutable.replaceSubrange(range, with: token)
        }

        return mutable
    }
}

private struct PlaceholderStore {
    private static let prefix = "@@MDPLACEHOLDER:"
    private static let suffix = "@@"

    private var values: [String] = []

    mutating func insert(_ html: String) -> String {
        values.append(html)
        return "\(Self.prefix)\(values.count - 1)\(Self.suffix)"
    }

    func resolve(in text: String) -> String {
        var result = text
        for (index, value) in values.enumerated() {
            let token = "\(Self.prefix)\(index)\(Self.suffix)"
            result = result.replacingOccurrences(of: token, with: value)
        }
        return result
    }
}

// MARK: - Escaping helpers

private func htmlEscape(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)

    for char in value {
        switch char {
        case "&":
            result.append("&amp;")
        case "<":
            result.append("&lt;")
        case ">":
            result.append("&gt;")
        case "\"":
            result.append("&quot;")
        default:
            result.append(char)
        }
    }

    return result
}

private func attributeEscape(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)

    for char in value {
        switch char {
        case "&":
            result.append("&amp;")
        case "\"":
            result.append("&quot;")
        case "'":
            result.append("&#39;")
        case "<":
            result.append("&lt;")
        case ">":
            result.append("&gt;")
        default:
            result.append(char)
        }
    }

    return result
}
