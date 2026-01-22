//
//  LibraryManager.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Library/LibraryManager.swift

import Foundation
import Combine

final class LibraryManager: ObservableObject {

    enum StartupState {
        case resolving
        case noLibrary
        case loaded(URL)
    }

    @Published private(set) var startupState: StartupState = .resolving

    // MARK: - Startup

    func resolveInitialLibrary() async {
        let config = await AppConfigStore.load()

        guard let url = config.lastLibraryURL else {
            startupState = .noLibrary
            return
        }

        // Validate the library still exists and is usable
        guard LibraryValidator.isLibraryRoot(url) else {
            startupState = .noLibrary
            return
        }

        startupState = .loaded(url)
    }

    // MARK: - Library lifecycle

    func setActiveLibrary(_ url: URL) async {
        startupState = .loaded(url)

        var config = await AppConfigStore.load()
        config.lastLibraryURL = url
        await AppConfigStore.save(config)
    }

    func clearLibrary() async {
        startupState = .noLibrary

        var config = await AppConfigStore.load()
        config.lastLibraryURL = nil
        await AppConfigStore.save(config)
    }
}
