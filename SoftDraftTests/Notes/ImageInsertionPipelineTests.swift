import XCTest
import AppKit
import UniformTypeIdentifiers
@testable import SoftDraft

@MainActor
final class ImageInsertionPipelineTests: XCTestCase {

    func testFileIngestionPersistsAndInsertsMarkdown() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let sourceURL = libraryURL.appendingPathComponent("sample.png")
        let imageData = try makeImageData(width: 24, height: 24)
        try imageData.write(to: sourceURL)

        let pipeline = ImageInsertionPipeline(dateProvider: { Date(timeIntervalSince1970: 1_000) })
        var insertedMarkdown: String?

        let outcome = await pipeline.run(
            source: .file(sourceURL),
            libraryURL: libraryURL
        ) { markdown in
            insertedMarkdown = markdown
            return true
        }

        XCTAssertTrue(outcome.succeeded)

        let assetsDirectory = libraryURL.appendingPathComponent("assets")
        let contents = try FileManager.default.contentsOfDirectory(
            atPath: assetsDirectory.path
        )

        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(insertedMarkdown, "![\(contents[0])](assets/\(contents[0]))")

        let storedData = try Data(
            contentsOf: assetsDirectory.appendingPathComponent(contents[0])
        )
        XCTAssertFalse(storedData.isEmpty)
    }

    func testClipboardIngestionFromPNGData() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let imageData = try makeImageData(width: 12, height: 12)

        let pasteboardName = NSPasteboard.Name("test-pipeline-\(UUID().uuidString)")
        let pasteboard = NSPasteboard(name: pasteboardName)
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .png)

        let pipeline = ImageInsertionPipeline(dateProvider: { Date(timeIntervalSince1970: 2_000) })
        var insertedMarkdown: String?

        let outcome = await pipeline.run(
            source: .clipboard({ @MainActor in pasteboard }),
            libraryURL: libraryURL
        ) { markdown in
            insertedMarkdown = markdown
            return true
        }

        XCTAssertTrue(outcome.succeeded)

        let contents = try FileManager.default.contentsOfDirectory(
            atPath: libraryURL.appendingPathComponent("assets").path
        )
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(insertedMarkdown, "![\(contents[0])](assets/\(contents[0]))")
    }

    func testRejectsOversizedImages() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let oversized = try makeImageData(width: 64, height: 64)
        let limit = max(oversized.count - 10, 1)

        let sourceURL = libraryURL.appendingPathComponent("large.png")
        try oversized.write(to: sourceURL)

        let pipeline = ImageInsertionPipeline(maxBytes: limit)

        let outcome = await pipeline.run(
            source: .file(sourceURL),
            libraryURL: libraryURL
        ) { _ in true }

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.failureReason, "Images must be 10 MB or smaller.")

        let contents = try FileManager.default.contentsOfDirectory(
            atPath: libraryURL.appendingPathComponent("assets").path
        )
        XCTAssertTrue(contents.isEmpty)
    }

    func testRemovesAssetWhenEditorInsertionFails() async throws {
        let libraryURL = try TestLibrary.makeTempLibrary()
        let sourceURL = libraryURL.appendingPathComponent("rollback.png")
        let imageData = try makeImageData(width: 16, height: 16)
        try imageData.write(to: sourceURL)

        let pipeline = ImageInsertionPipeline()

        let outcome = await pipeline.run(
            source: .file(sourceURL),
            libraryURL: libraryURL
        ) { _ in false }

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.failureReason, "SoftDraft couldn’t edit the note to add the image.")

        let contents = try FileManager.default.contentsOfDirectory(
            atPath: libraryURL.appendingPathComponent("assets").path
        )
        XCTAssertTrue(contents.isEmpty)
    }

    // MARK: - Helpers

    private func makeImageData(width: Int, height: Int) throws -> Data {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw XCTSkip("Unable to create color space")
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw XCTSkip("Unable to create context")
        }

        context.setFillColor(CGColor(red: 0.4, green: 0.2, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            throw XCTSkip("Unable to create CGImage")
        }

        guard let destinationData = CFDataCreateMutable(nil, 0) else {
            throw XCTSkip("Unable to allocate data buffer")
        }

        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw XCTSkip("Unable to create destination")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw XCTSkip("Unable to finalize image data")
        }

        return destinationData as Data
    }
}
