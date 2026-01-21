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
            if let libraryURL = libraryManager.libraryURL {
                LibraryLoadedView(libraryURL: libraryURL)
            } else {
                EmptyLibraryView()
            }
        }
    }
}
