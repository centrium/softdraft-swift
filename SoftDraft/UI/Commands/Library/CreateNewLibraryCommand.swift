//
//  CreateNewLibraryCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/02/2026.
//

import AppKit
import OSLog
import SwiftUI

private let createLibraryLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.softdraft.app",
    category: "CreateNewLibraryCommand"
)

let createNewLibraryCommand = AppCommand(
    id: "library.createNew",
    title: "New Library…",
    shortcut: KeyboardShortcut("n", modifiers: [.command, .shift]),
    isEnabled: { _ in
        true
    },
    perform: { ctx in
        createLibraryLogger.info("CreateLibraryCommand invoked")

        guard let selectedURL = promptForNewLibraryRoot() else {
            return
        }

        let targetURL = selectedURL.standardizedFileURL
        createLibraryLogger.info("New library canonical root: \(targetURL.path, privacy: .public)")

        if let rootValidationError = validateNewLibraryRootLocation(targetURL) {
            showCreateLibraryError(
                message: rootValidationError.message,
                informativeText: rootValidationError.informativeText
            )
            return
        }

        guard !hasActiveWatcherPointed(at: targetURL, libraryManager: ctx.libraryManager) else {
            showCreateLibraryError(
                message: "Cannot create a library at this location.",
                informativeText: "An active filesystem watcher is already attached to this path."
            )
            return
        }

        guard !hasLibraryMarkers(at: targetURL) else {
            createLibraryLogger.error("Validation failed: library exists")
            showCreateLibraryError(
                message: "A library already exists at this location.",
                informativeText: "Choose a different folder."
            )
            return
        }

        guard !isNestedInsideExistingLibrary(targetURL) else {
            createLibraryLogger.error("Validation failed: nested library")
            showCreateLibraryError(
                message: "Cannot create a library inside an existing library.",
                informativeText: "Choose a folder that is not inside another SoftDraft library."
            )
            return
        }

        do {
            try await createInitialLibraryStructure(at: targetURL)
            createLibraryLogger.info("Library folder structure created successfully")
            await ctx.libraryManager.setActiveLibrary(targetURL)
        } catch {
            showCreateLibraryError(
                message: "Unable to create library folders.",
                informativeText: error.localizedDescription
            )
        }
    }
)

@MainActor
private func promptForNewLibraryRoot() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.title = "Create New Library"
    panel.prompt = "Choose"
    return panel.runModal() == .OK ? panel.url : nil
}

private func hasLibraryMarkers(
    at url: URL,
    fileManager: FileManager = .default
) -> Bool {
    let markerPaths = [
        "assets",
        "collections",
        "LibraryIndex.json",
        ".softdraft/library.json"
    ]

    return markerPaths.contains { relativePath in
        let markerURL = url.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: markerURL.path)
    }
}

struct NewLibraryRootValidationError {
    let message: String
    let informativeText: String
}

func validateNewLibraryRootLocation(
    _ url: URL,
    fileManager: FileManager = .default
) -> NewLibraryRootValidationError? {
    let canonicalURL = url.standardizedFileURL
    let path = canonicalURL.path

    if path == "/" {
        return NewLibraryRootValidationError(
            message: "Cannot create a library at this location.",
            informativeText: "Choose a folder inside your home directory."
        )
    }

    let blockedSystemRoots = [
        "/System",
        "/Library",
        "/Applications",
        "/bin",
        "/sbin",
        "/usr"
    ]

    if blockedSystemRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
        return NewLibraryRootValidationError(
            message: "Cannot create a library in a system folder.",
            informativeText: "Choose a folder inside your home directory."
        )
    }

    let homeURL = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
    let homePath = homeURL.path
    let isInsideHome = path == homePath || path.hasPrefix(homePath + "/")

    if !isInsideHome {
        return NewLibraryRootValidationError(
            message: "Cannot create a library at this location.",
            informativeText: "Choose a folder inside your home directory."
        )
    }

    return nil
}

private func isNestedInsideExistingLibrary(
    _ url: URL,
    fileManager: FileManager = .default
) -> Bool {

    // Ensure we are working with a clean, absolute file URL
    let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL

    guard resolvedURL.isFileURL else {
        return false
    }

    var parent = resolvedURL.deletingLastPathComponent()
    var safetyCounter = 0

    while parent.path != "/" {

        if hasLibraryMarkers(at: parent, fileManager: fileManager) {
            return true
        }

        let next = parent.deletingLastPathComponent()

        // Defensive break (should never exceed 100 levels)
        safetyCounter += 1
        if safetyCounter > 100 {
            assertionFailure("Directory traversal exceeded safe depth.")
            return false
        }

        parent = next
    }

    return false
}

private func hasActiveWatcherPointed(
    at url: URL,
    libraryManager: LibraryManager
) -> Bool {
    guard libraryManager.filesystemWatcher != nil else {
        return false
    }

    guard let watchedRoot = libraryManager.activeLibraryURL?
        .standardizedFileURL
    else {
        return false
    }

    return watchedRoot.path == url.path
}

private func createMinimalLibraryStructure(
    at rootURL: URL,
    fileManager: FileManager = .default
) throws -> (assetsCreated: Bool, collectionsCreated: Bool) {
    var assetsCreated = false
    var collectionsCreated = false

    let requiredDirectories = ["assets", "collections"]

    for directoryName in requiredDirectories {
        let directoryURL = rootURL.appendingPathComponent(directoryName, isDirectory: true)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                continue
            }

            throw CocoaError(.fileWriteFileExists)
        }

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: false
        )

        if directoryName == "assets" {
            assetsCreated = true
        } else if directoryName == "collections" {
            collectionsCreated = true
        }
    }

    return (assetsCreated: assetsCreated, collectionsCreated: collectionsCreated)
}

func createInitialLibraryStructure(
    at rootURL: URL,
    fileManager: FileManager = .default
) async throws {
    _ = try createMinimalLibraryStructure(at: rootURL, fileManager: fileManager)

    let collectionsURL = rootURL.appendingPathComponent("collections", isDirectory: true)
    let inboxURL = collectionsURL.appendingPathComponent("Inbox", isDirectory: true)
    let inboxCreated = try createDirectoryIfNeeded(at: inboxURL, fileManager: fileManager)
    if inboxCreated {
        createLibraryLogger.info("Inbox created")
    }

    let welcomeURL = inboxURL.appendingPathComponent("Welcome.md")
    let welcomeCreated = try createWelcomeNoteIfNeeded(at: welcomeURL, fileManager: fileManager)
    if welcomeCreated {
        createLibraryLogger.info("Welcome note created")
    }

    var index = await buildIndexForInitialLibrary(at: rootURL)
    let welcomeNoteID = "Inbox/Welcome.md"

    if let existingNote = index.notes[welcomeNoteID], existingNote.state != .finished {
        index = LibraryIndexMutator.setState(
            index: index,
            noteID: welcomeNoteID,
            state: .finished
        )
        createLibraryLogger.info("Welcome note set to Finished")
    } else if index.notes[welcomeNoteID] != nil {
        createLibraryLogger.info("Welcome note set to Finished")
    }

    try persistLibraryIndex(index, at: rootURL, fileManager: fileManager)
}

private func createDirectoryIfNeeded(
    at directoryURL: URL,
    fileManager: FileManager = .default
) throws -> Bool {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
            return false
        }

        throw CocoaError(.fileWriteFileExists)
    }

    try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: false
    )
    return true
}

private func createWelcomeNoteIfNeeded(
    at welcomeURL: URL,
    fileManager: FileManager = .default
) throws -> Bool {
    guard !fileManager.fileExists(atPath: welcomeURL.path) else {
        return false
    }

    try welcomeNoteMarkdown.write(
        to: welcomeURL,
        atomically: true,
        encoding: .utf8
    )
    return true
}

private func buildIndexForInitialLibrary(at rootURL: URL) async -> LibraryIndex {
    let indexURL = libraryIndexURL(for: rootURL)
    let data = try? Data(contentsOf: indexURL)
    let decoded = data.flatMap { try? JSONDecoder().decode(LibraryIndex.self, from: $0) }
    let existingLibraryID = decoded?.libraryID ?? data.flatMap { LibraryIndexBuilder.extractLibraryID(from: $0) }

    return await LibraryIndexBuilder.build(
        libraryURL: rootURL,
        existingLibraryID: existingLibraryID,
        existingIndex: decoded
    )
}

private func persistLibraryIndex(
    _ index: LibraryIndex,
    at rootURL: URL,
    fileManager: FileManager = .default
) throws {
    let directory = rootURL.appendingPathComponent(".softdraft", isDirectory: true)
    let finalURL = libraryIndexURL(for: rootURL)
    let tmpURL = finalURL.appendingPathExtension("tmp")

    try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(index)
    try data.write(to: tmpURL, options: [.atomic])

    if fileManager.fileExists(atPath: finalURL.path) {
        _ = try fileManager.replaceItemAt(finalURL, withItemAt: tmpURL)
    } else {
        try fileManager.moveItem(at: tmpURL, to: finalURL)
    }
}

private func libraryIndexURL(for rootURL: URL) -> URL {
    rootURL
        .appendingPathComponent(".softdraft", isDirectory: true)
        .appendingPathComponent("library.json")
}

@MainActor
private func showCreateLibraryError(
    message: String,
    informativeText: String
) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = informativeText
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

private let welcomeNoteMarkdown = """
# Welcome to Your New Library

This is your Inbox.

Notes live inside collections.
Images you paste are saved automatically into the assets folder.
Switch between Edit and Preview to see your writing rendered.

Use the command menu to:
- Create notes
- Move notes
- Rename collections
- Organise your writing

Use ⌘K to run commands.

Start writing. Keep it calm.
"""
