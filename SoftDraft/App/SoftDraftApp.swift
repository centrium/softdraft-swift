//
//  SoftDraftApp.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI

@main
struct SoftdraftApp: App {

    @StateObject private var libraryManager = LibraryManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryManager)
                .task {
                    await libraryManager.resolveInitialLibrary()
                }
        }
        .commands {
            LibraryCommands(libraryManager: libraryManager)
        }
    }
}
