//
//  RevealCollectionInFinderCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import AppKit
import SwiftUI

let revealCollectionInFinderCommand = AppCommand(
    id: "collection.revealInFinder",
    title: "Reveal in Finder",
    shortcut: nil,
    isEnabled: { ctx, arguments in
        ctx.libraryURL != nil &&
        (arguments.collectionID ?? ctx.selection.selectedCollectionID) != nil
    },
    perform: { ctx, arguments in
        guard
            let libraryURL = ctx.libraryURL,
            let collectionID = arguments.collectionID ?? ctx.selection.selectedCollectionID
        else { return }

        let collectionURL = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)
            .appendingPathComponent(collectionID)
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([collectionURL])
        }
    }
)
