import XCTest
@testable import SoftDraft

final class MarkdownASTNormalizerTests: XCTestCase {
    private let normalizer = MarkdownASTNormalizer()

    func testNormalizerPromotesImageOnlyParagraphInBlockQuote() {
        let image = MarkdownImage(source: "local.png", alt: "Local")
        let document = MarkdownDocument(root: .blockQuote(children: [
            .paragraph(inlines: [.image(image)]),
        ]))

        let normalized = normalizer.normalize(document)

        guard case .blockQuote(let children) = normalized.root else {
            return XCTFail("Expected block quote root")
        }
        XCTAssertEqual(children.count, 1)
        guard case .image(let normalizedImage) = children[0] else {
            return XCTFail("Expected image block inside block quote")
        }
        XCTAssertEqual(normalizedImage, image)
    }

    func testNormalizerPromotesImageOnlyParagraphInListItems() {
        let image = MarkdownImage(source: "https://example.com/image.png", alt: "Remote")
        let listItem = MarkdownListItem(blocks: [
            .paragraph(inlines: [.image(image)]),
        ])
        let taskItem = MarkdownTaskListItem(checked: false, blocks: [
            .paragraph(inlines: [.image(image)]),
        ])
        let document = MarkdownDocument(root: .list(style: .unordered, items: [
            .listItem(listItem),
            .taskItem(taskItem),
        ]))

        let normalized = normalizer.normalize(document)

        guard case .list(_, let items) = normalized.root else {
            return XCTFail("Expected list root")
        }
        XCTAssertEqual(items.count, 2)

        guard case .listItem(let normalizedListItem) = items[0] else {
            return XCTFail("Expected list item")
        }
        guard case .image(let listImage) = normalizedListItem.blocks.first else {
            return XCTFail("Expected image block in list item")
        }
        XCTAssertEqual(listImage, image)

        guard case .taskItem(let normalizedTaskItem) = items[1] else {
            return XCTFail("Expected task item")
        }
        guard case .image(let taskImage) = normalizedTaskItem.blocks.first else {
            return XCTFail("Expected image block in task item")
        }
        XCTAssertEqual(taskImage, image)
    }

    func testNormalizerLeavesMixedParagraphUnchanged() {
        let image = MarkdownImage(source: "image.png", alt: "Example")
        let paragraph: MarkdownBlock = .paragraph(inlines: [
            .text("Before "),
            .image(image),
            .text(" after"),
        ])
        let document = MarkdownDocument(root: .document(blocks: [paragraph]))

        let normalized = normalizer.normalize(document)

        guard case .document(let blocks) = normalized.root else {
            return XCTFail("Expected document root")
        }
        XCTAssertEqual(blocks.count, 1)
        guard case .paragraph(let inlines) = blocks[0] else {
            return XCTFail("Expected paragraph to remain")
        }
        XCTAssertEqual(inlines.count, 3)
    }

    func testNormalizerDoesNotTouchTables() {
        let image = MarkdownImage(source: "image.png", alt: nil)
        let table = MarkdownTable(
            alignments: [.unspecified],
            header: MarkdownTableRow(cells: [[.text("Header")]]),
            rows: [
                MarkdownTableRow(cells: [[.image(image)]]),
            ]
        )
        let document = MarkdownDocument(root: .document(blocks: [
            .table(table),
        ]))

        let normalized = normalizer.normalize(document)

        XCTAssertEqual(normalized.root, document.root)
    }
}
