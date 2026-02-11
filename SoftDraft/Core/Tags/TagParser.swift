//
//  TagParser.swift
//  SoftDraft
//

import Foundation

enum TagParser {
    private static let tagRegex = try! NSRegularExpression(
        pattern: "(?<!\\w)#([A-Za-z0-9][A-Za-z0-9_-]*)",
        options: []
    )

    private static let fencedCodeRegex = try! NSRegularExpression(
        pattern: "(?s)```.*?```|~~~.*?~~~",
        options: []
    )

    private static let inlineCodeRegex = try! NSRegularExpression(
        pattern: "`[^`\\n]*`",
        options: []
    )

    static func parseTags(from markdown: String) -> Set<String> {
        let withoutFencedCode = replaceMatches(
            in: markdown,
            using: fencedCodeRegex,
            with: " "
        )

        let withoutInlineCode = replaceMatches(
            in: withoutFencedCode,
            using: inlineCodeRegex,
            with: " "
        )

        let range = NSRange(withoutInlineCode.startIndex..., in: withoutInlineCode)
        let matches = tagRegex.matches(in: withoutInlineCode, options: [], range: range)

        var tags = Set<String>()
        tags.reserveCapacity(matches.count)

        for match in matches {
            guard
                match.numberOfRanges > 1,
                let range = Range(match.range(at: 1), in: withoutInlineCode)
            else {
                continue
            }

            tags.insert(withoutInlineCode[range].lowercased())
        }

        return tags
    }

    private static func replaceMatches(
        in text: String,
        using regex: NSRegularExpression,
        with replacement: String
    ) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }
}
