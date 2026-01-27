//
//  RootView 2.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation
import SwiftUI

struct RootView: View {

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @EnvironmentObject private var selection: SelectionModel

    var body: some View {
        Group {
            switch libraryManager.startupState {

            case .resolving:
                StartupPlaceholderView()

            case .noLibrary:
                EmptyLibraryView()

            case .loaded(let url):
                LibraryLoadedView(
                    libraryURL: url
                )
            }
        }
        .focusable(selection.pendingMove != nil)
        .onExitCommand {
            commandRegistry.run("command.cancel")
        }
    }
}
