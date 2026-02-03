import XCTest
@testable import SoftDraft

final class MarkdownASTParserTests: XCTestCase {

    private let parser = MarkdownASTParser()

    func testNestedEmphasisProducesInlineTree() {
        let source = "Before *outer **inner** outer* after"
        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        guard blocks.count == 1,
              case .paragraph(let inlines) = blocks.first else {
            return XCTFail("Expected single paragraph")
        }

        XCTAssertEqual(inlines.count, 3)
        guard case .emphasis(let outerChildren) = inlines[1] else {
            return XCTFail("Expected emphasis node")
        }
        XCTAssertEqual(outerChildren.count, 3)
        guard case .strong(let innerChildren) = outerChildren[1] else {
            return XCTFail("Expected nested strong node")
        }
        XCTAssertEqual(innerChildren, [.text("inner")])
    }

    func testTableWithInlineFormatting() {
        let source = """
        | Column A | Column B |
        | :--- | ---: |
        | *Left* | **Right** |
        """

        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        guard blocks.count == 1,
              case .table(let table) = blocks.first else {
            return XCTFail("Expected table as first block")
        }

        XCTAssertEqual(table.alignments, [.left, .right])
        XCTAssertEqual(table.header?.cells.count, 2)
        XCTAssertEqual(table.rows.count, 1)
        guard let firstRow = table.rows.first else {
            return XCTFail("Missing body row")
        }
        XCTAssertEqual(firstRow.cells.count, 2)
        guard case .emphasis = firstRow.cells[0].first else {
            return XCTFail("Expected emphasis inline inside table cell")
        }
        guard case .strong = firstRow.cells[1].first else {
            return XCTFail("Expected strong inline inside table cell")
        }
    }

    func testMalformedTableFallsBackToParagraphs() {
        let source = """
        | Column A | Column B |
        | --- invalid |
        | Value | Value |
        """

        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertFalse(blocks.contains { block in
            if case .table = block { return true }
            return false
        })
        XCTAssertTrue(blocks.allSatisfy { block in
            if case .paragraph = block { return true }
            return false
        })
    }

    func testInlineHighlightProducesDedicatedNode() {
        let source = "Mix ==very *important*== details"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertTrue(inlines.contains { inline in
            if case .highlight = inline { return true }
            return false
        })

        guard inlines.count >= 3,
              case .highlight(let children) = inlines[1] else {
            return XCTFail("Expected highlight as middle inline")
        }

        XCTAssertEqual(children.count, 2)
        guard case .text(let prefix) = children.first else {
            return XCTFail("Expected text child inside highlight")
        }
        XCTAssertEqual(prefix, "very ")
        guard case .emphasis(let nested) = children.last else {
            return XCTFail("Expected emphasis child inside highlight")
        }
        XCTAssertEqual(nested, [.text("important")])
    }

    func testHighlightFallsBackWhenUnmatched() {
        let source = "Broken ==highlight"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertFalse(inlines.contains { inline in
            if case .highlight = inline { return true }
            return false
        })
        XCTAssertEqual(concatenatedText(inlines), source)
    }

    func testAutolinkStandaloneURL() {
        let source = "http://example.com"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 1)
        guard case .link(let link) = inlines.first else {
            return XCTFail("Expected autolink inline")
        }
        XCTAssertEqual(link.destination, "http://example.com")
        XCTAssertEqual(link.title, nil)
        XCTAssertEqual(link.children, [.text("http://example.com")])
    }

    func testAutolinkInSentence() {
        let source = "See http://example.com for details"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 3)
        guard case .text("See ") = inlines[0] else {
            return XCTFail("Expected leading text inline")
        }
        guard case .link(let link) = inlines[1] else {
            return XCTFail("Expected middle autolink inline")
        }
        XCTAssertEqual(link.destination, "http://example.com")
        XCTAssertEqual(link.children, [.text("http://example.com")])
        guard case .text(" for details") = inlines[2] else {
            return XCTFail("Expected trailing text inline")
        }
    }

    func testAutolinkMultipleLinks() {
        let source = "Links http://a.com and https://b.com"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 4)
        guard case .text("Links ") = inlines[0] else {
            return XCTFail("Expected leading text inline")
        }
        guard case .link(let firstLink) = inlines[1] else {
            return XCTFail("Expected first autolink inline")
        }
        XCTAssertEqual(firstLink.destination, "http://a.com")
        guard case .text(" and ") = inlines[2] else {
            return XCTFail("Expected separator text inline")
        }
        guard case .link(let secondLink) = inlines[3] else {
            return XCTFail("Expected second autolink inline")
        }
        XCTAssertEqual(secondLink.destination, "https://b.com")
    }

    func testAutolinkTrimsTrailingPunctuation() {
        let source = "Visit http://example.com."
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 3)
        guard case .text("Visit ") = inlines[0] else {
            return XCTFail("Expected prefix text inline")
        }
        guard case .link(let link) = inlines[1] else {
            return XCTFail("Expected trimmed autolink inline")
        }
        XCTAssertEqual(link.destination, "http://example.com")
        guard case .text(".") = inlines[2] else {
            return XCTFail("Expected trailing punctuation inline")
        }
    }

    func testAutolinkIgnoredInsideLinkLabel() {
        let source = "[http://example.com](https://dest.com)"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 1)
        guard case .link(let link) = inlines.first else {
            return XCTFail("Expected parsed link inline")
        }
        XCTAssertEqual(link.destination, "https://dest.com")
        XCTAssertEqual(link.children, [.text("http://example.com")])
    }

    func testStrikethroughProducesInlineNode() {
        let source = "This ~~very *important*~~ text"
        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .paragraph(let inlines) = block else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(inlines.count, 3)
        guard case .text("This ") = inlines[0] else {
            return XCTFail("Expected leading text segment")
        }
        guard case .strikethrough(let children) = inlines[1] else {
            return XCTFail("Expected middle strikethrough inline")
        }
        XCTAssertEqual(children.count, 2)
        guard case .text("very ") = children[0] else {
            return XCTFail("Expected nested text in strikethrough")
        }
        guard case .emphasis(let emphasisChildren) = children[1] else {
            return XCTFail("Expected emphasis inside strikethrough")
        }
        XCTAssertEqual(emphasisChildren, [.text("important")])
        guard case .text(" text") = inlines[2] else {
            return XCTFail("Expected trailing text segment")
        }
    }

    func testTaskItemsProduceDedicatedNodes() {
        let source = """
        - [ ] Todo **one**
        - [] Sparse
        - [x] Done
        - Plain text
        """

        let document = parser.parse(source)
        guard let block = rootBlocks(in: document).first,
              case .list(let style, let items) = block else {
            return XCTFail("Expected list block")
        }

        if case .unordered = style {
            // expected
        } else {
            XCTFail("Expected unordered style")
        }

        XCTAssertEqual(items.count, 4)

        guard case .taskItem(let firstTask) = items[0] else {
            return XCTFail("Expected first item to be task")
        }
        XCTAssertFalse(firstTask.checked)
        XCTAssertTrue(containsStrong(in: firstTask.blocks))

        guard case .taskItem(let secondTask) = items[1] else {
            return XCTFail("Expected second item to be unchecked task")
        }
        XCTAssertFalse(secondTask.checked)

        guard case .taskItem(let thirdTask) = items[2] else {
            return XCTFail("Expected third item to be checked task")
        }
        XCTAssertTrue(thirdTask.checked)

        guard case .listItem = items[3] else {
            return XCTFail("Expected final item to remain standard list item")
        }
    }

    func testMermaidBlockCapturedVerbatim() {
        let source = """
        ```mermaid
        graph TD;
        A-->B
        ```
        """

        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        guard blocks.count == 1,
              case .mermaidBlock(let source) = blocks.first else {
            return XCTFail("Expected mermaid block")
        }
        XCTAssertTrue(source.contains("graph TD"))
        XCTAssertTrue(source.contains("A-->B"))
    }

    func testMathBlocksAndInlineMath() {
        let source = """
        Intro paragraph.

        $$
        a^2 + b^2
        $$

        Result is $c^2$ overall.
        """

        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        XCTAssertEqual(blocks.count, 3)
        guard case .mathBlock(let mathSource) = blocks[1] else {
            return XCTFail("Expected math block in middle")
        }
        XCTAssertEqual(mathSource.trimmingCharacters(in: .whitespacesAndNewlines), "a^2 + b^2")

        guard case .paragraph(let finalParagraph) = blocks[2] else {
            return XCTFail("Expected trailing paragraph")
        }
        XCTAssertTrue(finalParagraph.contains(where: { inline in
            if case .mathInline = inline { return true }
            return false
        }))
        XCTAssertFalse(finalParagraph.contains { inline in
            if case .text(let value) = inline {
                return value.contains("$")
            }
            return false
        })
    }

    func testDanglingInlineMathFallsBackToText() {
        let source = "Price is $ per unit"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(concatenatedText(inlines), source)
        XCTAssertFalse(inlines.contains { inline in
            if case .mathInline = inline { return true }
            return false
        })
    }

    func testInlineDoubleDollarMathProducesSingleNode() {
        let source = "Inline $$a^2 + b^2$$ markers"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        let mathContents = inlines.compactMap { inline -> String? in
            if case .mathInline(let value) = inline {
                return value
            }
            return nil
        }
        XCTAssertEqual(mathContents, ["a^2 + b^2"])
        XCTAssertFalse(inlines.contains { inline in
            if case .text(let value) = inline {
                return value.contains("$$")
            }
            return false
        })
    }

    func testBlockMathWithoutClosingFallsBackToParagraph() {
        let source = """
        $$
        Unfinished block
        """

        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected fallback paragraph")
        }

        XCTAssertTrue(inlines.contains { inline in
            if case .text(let value) = inline {
                return value.contains("$$")
            }
            return false
        })
        XCTAssertFalse(inlines.contains { inline in
            if case .mathInline = inline { return true }
            return false
        })
    }

    func testBlockMathCapturesNewlinesInSingleNode() {
        let source = """
        $$
        a^2 + b^2

        = c^2
        $$
        """

        let document = parser.parse(source)
        let blocks = rootBlocks(in: document)
        guard blocks.count == 1,
              case .mathBlock(let payload) = blocks.first else {
            return XCTFail("Expected math block")
        }

        XCTAssertTrue(payload.contains("a^2 + b^2"))
        XCTAssertTrue(payload.contains("= c^2"))
        XCTAssertEqual(payload.components(separatedBy: "\n").count, 3)
    }

    func testEmptyInlineCodeBackticksRemainText() {
        let source = "``"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(concatenatedText(inlines), source)
        XCTAssertFalse(containsInlineCode(inlines))
    }

    func testMissingInlineCodeCloserFallsBackToText() {
        let source = "Prefix `unterminated"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(concatenatedText(inlines), source)
        XCTAssertFalse(containsInlineCode(inlines))
    }

    func testDanglingLinkSyntaxRemainsLiteral() {
        let source = "This [link](never closes"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(concatenatedText(inlines), source)
        XCTAssertFalse(containsLink(inlines))
    }

    func testDanglingImageSyntaxRemainsLiteral() {
        let source = "Image ![broken"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertEqual(concatenatedText(inlines), source)
        XCTAssertFalse(containsImage(inlines))
    }

    func testMalformedMarkdownFallsBackToText() {
        let source = "*broken _markdown"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph fallback")
        }
        XCTAssertEqual(inlines, [.text("*broken _markdown")])
    }

    func testBareURLAutoLinksInParagraph() {
        let source = "Visit https://example.com for details"
        let document = parser.parse(source)
        guard let first = rootBlocks(in: document).first,
              case .paragraph(let inlines) = first else {
            return XCTFail("Expected paragraph")
        }
        XCTAssertEqual(inlines.count, 3)
        guard case .text("Visit ") = inlines[0] else {
            return XCTFail("Expected leading text inline")
        }
        guard case .link(let link) = inlines[1] else {
            return XCTFail("Expected autolink inline")
        }
        XCTAssertEqual(link.destination, "https://example.com")
        guard case .text(" for details") = inlines[2] else {
            return XCTFail("Expected trailing text inline")
        }
    }

    private func rootBlocks(in document: MarkdownDocument) -> [MarkdownBlock] {
        if case .document(let blocks) = document.root {
            return blocks
        }
        return []
    }

    private func concatenatedText(_ inlines: [MarkdownInline]) -> String {
        inlines.compactMap { inline in
            if case .text(let value) = inline {
                return value
            }
            return nil
        }.joined()
    }

    private func containsInlineCode(_ inlines: [MarkdownInline]) -> Bool {
        inlines.contains { inline in
            if case .inlineCode = inline {
                return true
            }
            return false
        }
    }

    private func containsLink(_ inlines: [MarkdownInline]) -> Bool {
        inlines.contains { inline in
            if case .link = inline {
                return true
            }
            return false
        }
    }

    private func containsImage(_ inlines: [MarkdownInline]) -> Bool {
        inlines.contains { inline in
            if case .image = inline {
                return true
            }
            return false
        }
    }

    private func containsStrong(in blocks: [MarkdownBlock]) -> Bool {
        for block in blocks {
            if case .paragraph(let inlines) = block {
                if inlines.contains(where: { inline in
                    if case .strong = inline { return true }
                    return false
                }) {
                    return true
                }
            }
        }
        return false
    }
}
