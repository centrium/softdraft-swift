//
//  LibraryManager+.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation

extension LibraryManager {

    var currentLibraryURL: URL? {
        guard case .loaded(let url) = startupState else {
            return nil
        }
        return url
    }
}
