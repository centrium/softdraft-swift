//
//  LibraryManager.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Library/LibraryManager.swift

import Foundation
import Combine

@MainActor
final class LibraryManager: ObservableObject {
    
    @Published private(set) var libraryURL: URL? {
            didSet {
                print("📚 libraryURL set to:", libraryURL?.path ?? "nil")
            }
        }

    func resolveInitialLibrary() async {
        // Load config and validate off main actor
        let (urlResult, resetConfig) = await Task.detached(priority: .userInitiated) { () -> (URL?, Bool) in
            let cfg = await AppConfigStore.load()

            guard let url = cfg.lastLibraryURL else {
                return (nil, false)
            }

            do {
                guard LibraryValidator.isLibraryRoot(url) else {
                    throw CoreError.invalidLibrary
                }

                try LibraryValidator.ensureLibraryStructure(at: url)
                return (url, false)
            } catch {
                return (nil, true)
            }
        }.value

        if resetConfig {
            await AppConfigStore.save(.init())
        }

        libraryURL = urlResult
    }

    func setActiveLibrary(_ url: URL) async throws {
        // Validate off main actor first
        try await Task.detached(priority: .userInitiated) {
            guard LibraryValidator.isLibraryRoot(url) else {
                throw CoreError.invalidLibrary
            }
            try LibraryValidator.ensureLibraryStructure(at: url)
        }.value

        libraryURL = url

        await AppConfigStore.save(.init(lastLibraryURL: url))
    }
}
