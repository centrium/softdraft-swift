//
//  AppConfig.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/AppConfig/AppConfig.swift

import Foundation

struct AppConfig: Codable {
    var lastLibraryURL: URL?

    init(lastLibraryURL: URL? = nil) {
        self.lastLibraryURL = lastLibraryURL
    }
}
