//
//  RebuildLibraryIndexCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import SwiftUI

let rebuildLibraryIndexCommand = AppCommand(
    id: "library.index.rebuild",
    title: "Rebuild Library Index",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.libraryURL != nil
    },
    perform: { ctx in
        guard let libraryURL = ctx.libraryURL else { return }
        await ctx.libraryManager.rebuildLibraryIndex(
            libraryURL: libraryURL
        )
    }
)
