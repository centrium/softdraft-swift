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

    var body: some View {
        Group {
            switch libraryManager.startupState {

            case .resolving:
                StartupPlaceholderView()

            case .noLibrary:
                EmptyLibraryView()

            case .loaded(let url):
                LibraryLoadedView(libraryURL: url)
            }
        }
        .task {
            await libraryManager.resolveInitialLibrary()
        }
    }
}
