//
//  ImageInsertionPipeline.swift
//  SoftDraft
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageInsertionPipeline {

    struct Outcome {
        let succeeded: Bool
        let failureReason: String?
        let encounteredImage: Bool

        static var success: Outcome {
            Outcome(succeeded: true, failureReason: nil, encounteredImage: true)
        }

        static func failure(reason: String?, encounteredImage: Bool) -> Outcome {
            Outcome(succeeded: false, failureReason: reason, encounteredImage: encounteredImage)
        }
    }

    enum Source {
        case clipboard(NSPasteboard)
        case file(URL)
    }

    typealias TextInsertionHandler = @Sendable (String) async -> Bool

    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let maxBytes: Int

    init(
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        maxBytes: Int = 10 * 1_024 * 1_024
    ) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.maxBytes = maxBytes
    }

    func run(
        source: Source,
        libraryURL: URL,
        insertMarkdown: @escaping TextInsertionHandler
    ) async -> Outcome {

        let loadResult = await loadRepresentation(from: source)

        let representation: ImageRepresentation

        switch loadResult {
        case .success(let value):
            representation = value
        case .failure(let message):
            log("Representation failure for source \(sourceDescription(source)): \(message)")
            return .failure(reason: message, encounteredImage: true)
        case .noImage:
            log("No image data detected on source \(sourceDescription(source))")
            return .failure(reason: nil, encounteredImage: false)
        }

        guard representation.data.count <= maxBytes else {
            log("Image exceeds max size of \(maxBytes) bytes")
            return .failure(reason: "Images must be 10 MB or smaller.", encounteredImage: true)
        }

        guard let destination = write(
            representation: representation,
            libraryURL: libraryURL
        ) else {
            log("Failed to write image to assets directory")
            return .failure(reason: "SoftDraft couldn’t save the image to the library.", encounteredImage: true)
        }

        let markdown = "![\(destination.filename)](assets/\(destination.filename))"

        let inserted = await insertMarkdown(markdown)

        guard inserted else {
            try? fileManager.removeItem(at: destination.fileURL)
            log("Editor rejected markdown insertion; cleaned up \(destination.filename)")
            return .failure(reason: "SoftDraft couldn’t edit the note to add the image.", encounteredImage: true)
        }

        return .success
    }

    // MARK: - Representation loading

    private func loadRepresentation(from source: Source) async -> LoadResult {
        switch source {
        case .file(let url):
            return loadFileRepresentation(url)
        case .clipboard(let pasteboard):
            return await MainActor.run {
                loadClipboardRepresentation(pasteboard)
            }
        }
    }

    private func loadFileRepresentation(_ url: URL) -> LoadResult {
        guard url.isFileURL else {
            log("Provided file URL is not a file URL: \(url)")
            return .failure("SoftDraft couldn’t read that file.")
        }

        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
           size > maxBytes {
            log("File size \(size) exceeds limit \(maxBytes)")
            return .failure("Images must be 10 MB or smaller.")
        }

        guard let data = try? Data(contentsOf: url) else {
            log("Failed to read data from url: \(url)")
            return .failure("SoftDraft couldn’t read that file.")
        }

        let ext = url.pathExtension
        let typeHint = ext.isEmpty ? nil : UTType(filenameExtension: ext.lowercased())

        if let normalized = normalizedRepresentation(
            from: data,
            typeHint: typeHint
        ) {
            return .success(normalized)
        }

        return .failure("SoftDraft couldn’t read that image format.")
    }

    @MainActor
    private func loadClipboardRepresentation(_ pasteboard: NSPasteboard) -> LoadResult {
        if let fileURLString = pasteboard.propertyList(forType: .fileURL) as? String,
           let fileURL = URL(string: fileURLString),
           fileURL.isFileURL {
            let result = loadFileRepresentation(fileURL)
            if case .success = result { return result }
            if case .failure = result { return result }
        }

        for candidate in Self.clipboardTypes {
            if let data = pasteboard.data(forType: candidate.pasteboardType) {
                if let normalized = normalizedRepresentation(
                    from: data,
                    typeHint: candidate.utType
                ) {
                    return .success(normalized)
                } else {
                    return .failure("SoftDraft couldn’t read that clipboard image.")
                }
            }
        }

        if let image = NSImage(pasteboard: pasteboard) {
            if let encoded = encode(image: image) {
                return .success(encoded)
            } else {
                return .failure("SoftDraft couldn’t read that clipboard image.")
            }
        }

        return .noImage
    }

    // MARK: - Encoding helpers

    private func normalizedRepresentation(
        from data: Data,
        typeHint: UTType?
    ) -> ImageRepresentation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            log("CGImageSource creation failed")
            return nil
        }

        let resolvedType: UTType? = {
            if let cfType = CGImageSourceGetType(source) {
                return UTType(cfType as String)
            }
            return typeHint
        }()

        if let resolvedType,
           resolvedType.conforms(to: .png) || resolvedType.conforms(to: .jpeg) {
            guard data.count <= maxBytes else {
                log("Normalized data exceeds max size")
                return nil
            }
            let ext = resolvedType.preferredFilenameExtension ?? extensionForResolvedType(resolvedType)
            return ImageRepresentation(data: data, fileExtension: ext)
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            log("Failed to create CGImage from source")
            return nil
        }

        return encode(cgImage: image, preferredType: .png)
    }

    private func encode(image: NSImage) -> ImageRepresentation? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            log("NSImage conversion to CGImage failed")
            return nil
        }

        return encode(cgImage: cgImage, preferredType: .png)
    }

    private func encode(
        cgImage: CGImage,
        preferredType: UTType
    ) -> ImageRepresentation? {
        guard let data = encodeData(from: cgImage, type: preferredType) else {
            log("Failed to encode CGImage as \(preferredType.identifier)")
            return nil
        }

        guard data.count <= maxBytes else {
            log("Encoded image exceeds max size")
            return nil
        }

        return ImageRepresentation(
            data: data,
            fileExtension: preferredType.preferredFilenameExtension ?? extensionForResolvedType(preferredType)
        )
    }

    private func encodeData(
        from image: CGImage,
        type: UTType
    ) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0) else {
            log("Unable to allocate CFMutableData")
            return nil
        }

        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            type.identifier as CFString,
            1,
            nil
        ) else {
            log("Failed to create CGImageDestination for type \(type.identifier)")
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            log("CGImageDestinationFinalize failed for type \(type.identifier)")
            return nil
        }

        return mutableData as Data
    }

    private func extensionForResolvedType(_ type: UTType) -> String {
        if type.conforms(to: .jpeg) { return "jpg" }
        return "png"
    }

    // MARK: - Persistence

    private func write(
        representation: ImageRepresentation,
        libraryURL: URL
    ) -> Destination? {
        let assetsURL = libraryURL.appendingPathComponent("assets", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: assetsURL,
                withIntermediateDirectories: true
            )
        } catch {
            log("Failed to create assets directory: \(error.localizedDescription)")
            return nil
        }

        let baseName = Self.filenameFormatter.string(from: dateProvider())
        var attempt = 0

        while attempt < 50 {
            let suffix = attempt == 0 ? "" : "-\(attempt)"
            let filename = "\(baseName)\(suffix).\(representation.fileExtension)"
            let destination = assetsURL.appendingPathComponent(filename)

            if !fileManager.fileExists(atPath: destination.path) {
                do {
                    try representation.data.write(to: destination, options: .atomic)
                    return Destination(fileURL: destination, filename: filename)
                } catch {
                    log("Failed to write image data to \(destination): \(error.localizedDescription)")
                    return nil
                }
            }

            attempt += 1
        }

        log("Exceeded filename attempts for base \(baseName)")
        return nil
    }

    // MARK: - Types

    private struct ImageRepresentation {
        let data: Data
        let fileExtension: String
    }

    private struct Destination {
        let fileURL: URL
        let filename: String
    }

    private static let clipboardTypes: [ClipboardImageType] = [
        ClipboardImageType(type: NSPasteboard.PasteboardType("public.png"), utType: .png),
        ClipboardImageType(type: NSPasteboard.PasteboardType("public.jpeg"), utType: .jpeg),
        ClipboardImageType(type: NSPasteboard.PasteboardType("public.jpeg-2000"), utType: nil),
        ClipboardImageType(type: .tiff, utType: .tiff)
    ]

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private struct ClipboardImageType {
        let pasteboardType: NSPasteboard.PasteboardType
        let utType: UTType?

        init(type: NSPasteboard.PasteboardType, utType: UTType?) {
            self.pasteboardType = type
            self.utType = utType
        }
    }

    private func log(_ message: String) {
        print("[ImageInsertionPipeline] \(message)")
    }

    private func sourceDescription(_ source: Source) -> String {
        switch source {
        case .clipboard:
            return "clipboard"
        case .file(let url):
            return url.path
        }
    }

    private enum LoadResult {
        case success(ImageRepresentation)
        case failure(String)
        case noImage
    }
}
