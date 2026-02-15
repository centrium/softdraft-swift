//
//  InsertImageCommands.swift
//  SoftDraft
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

let insertImageFromFileCommand = AppCommand(
    id: "note.insertImage.fromFile",
    title: "Insert Image…",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.libraryURL != nil && ctx.selection.selectedNoteID != nil
    },
    perform: { ctx in
        guard let libraryURL = ctx.libraryURL else { return }

        guard let url = await MainActor.run(body: {
            chooseImageURL()
        }) else { return }

        _ = await runImagePipeline(
            context: ctx,
            source: .file(url),
            libraryURL: libraryURL
        )
    }
)

let handlePasteCommand = AppCommand(
    id: "edit.paste",
    title: "Paste",
    shortcut: KeyboardShortcut("v", modifiers: [.command]),
    isEnabled: { _ in true },
    perform: { ctx in
        guard
            let libraryURL = ctx.libraryURL,
            ctx.selection.selectedNoteID != nil
        else {
            await MainActor.run {
                EditorTextInsertion.paste()
            }
            return
        }

        let outcome = await runImagePipeline(
            context: ctx,
            source: .clipboard({ @MainActor in NSPasteboard.general }),
            libraryURL: libraryURL
        )

        if !outcome.succeeded && !outcome.encounteredImage {
            await MainActor.run {
                EditorTextInsertion.paste()
            }
        }
    }
)

// MARK: - Helpers

private func chooseImageURL() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.image]

    return panel.runModal() == .OK ? panel.url : nil
}

private func runImagePipeline(
    context: CommandContext,
    source: ImageInsertionPipeline.Source,
    libraryURL: URL
) async -> ImageInsertionPipeline.Outcome {
    let pipeline = ImageInsertionPipeline()

    await MainActor.run {
        withAnimation(AppMotion.standard) {
            context.uiState.isInsertingImage = true
        }
        context.uiState.imageInsertionError = nil
    }

    let outcome = await pipeline.run(
        source: source,
        libraryURL: libraryURL
    ) { markdown in
        await MainActor.run {
            EditorTextInsertion.insertMarkdown(markdown)
        }
    }

    await MainActor.run {
        withAnimation(AppMotion.standard) {
            context.uiState.isInsertingImage = false
        }
        if !outcome.succeeded, let reason = outcome.failureReason {
            context.uiState.imageInsertionError = reason
        }
    }

    return outcome
}
