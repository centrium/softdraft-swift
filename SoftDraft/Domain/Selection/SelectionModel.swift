//
//  SelectionModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation
import Combine

struct PendingMove {
    let noteID: String
    let destinationCollection: String?
}

struct PendingCollectionRename {
    let originalID: String
}

@MainActor
final class SelectionModel: ObservableObject {

    @Published var selectedCollectionID: String? = nil
    @Published var selectedNoteID: String? = nil
    @Published var pendingCollectionRename: PendingCollectionRename? = nil
    @Published var collectionRenameDraft: String = ""

    @Published var pendingMove: PendingMove? = nil
    private var resolvePreviewModeForNoteID: ((String) -> Bool)?
    private var resolveCurrentNoteTextForNoteID: ((String) -> String)?
    private var applyPreviewMode: ((Bool) -> Void)?
    private var applyCurrentNoteText: ((String) -> Void)?

    func configurePreviewModeResolver(
        resolve: @escaping (String) -> Bool,
        applyPreview: @escaping (Bool) -> Void,
        resolveText: @escaping (String) -> String,
        applyText: @escaping (String) -> Void
    ) {
        resolvePreviewModeForNoteID = resolve
        applyPreviewMode = applyPreview
        resolveCurrentNoteTextForNoteID = resolveText
        applyCurrentNoteText = applyText
    }

    func selectCollection(_ id: String?) {
        selectedCollectionID = id
        selectNote(nil)
        pendingMove = nil
    }

    func selectNote(_ id: String?) {
        let previousNoteID = selectedNoteID
        print("Switch note:", previousNoteID ?? "nil", "->", id ?? "nil")

        if let id,
           let resolveCurrentNoteTextForNoteID,
           let resolvePreviewModeForNoteID,
           let applyCurrentNoteText,
           let applyPreviewMode {
            let resolvedText = resolveCurrentNoteTextForNoteID(id)
            applyCurrentNoteText(resolvedText)

            selectedNoteID = id

            let isPreview = resolvePreviewModeForNoteID(id)
            applyPreviewMode(isPreview)
            print("Preview mode before render:", isPreview)
            return
        } else {
            applyCurrentNoteText?("")
            selectedNoteID = nil
            applyPreviewMode?(false)
            print("Preview mode before render:", false)
            return
        }
    }

    func clearNoteSelection() {
        selectNote(nil)
        pendingMove = nil
    }
    
    func beginRenameCollection(_ id: String) {
        pendingCollectionRename = PendingCollectionRename(originalID: id)
        collectionRenameDraft = id
    }

    func cancelRenameCollection() {
        pendingCollectionRename = nil
        collectionRenameDraft = ""
    }
}
