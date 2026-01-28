//
//  CommandContext.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation

// Commands/CommandContext.swift

struct CommandContext {

    let libraryManager: LibraryManager
    let selection: SelectionModel

    var libraryURL: URL? {
        libraryManager.currentLibraryURL
    }
}
