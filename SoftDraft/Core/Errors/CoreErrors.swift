//
//  CoreErrors.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Errors/CoreError.swift
import Foundation

enum CoreError: Error, LocalizedError {
    case noLibraryLoaded
    case invalidLibrary
    case invalidNoteID
    case noteNotFound
    case invalidContent
    case collectionNotFound

    var errorDescription: String? {
        switch self {
        case .noLibraryLoaded: return "No library loaded"
        case .invalidLibrary: return "Not a valid Softdraft library"
        case .invalidNoteID: return "Invalid note id"
        case .noteNotFound: return "Note not found"
        case .invalidContent: return "Invalid note content"
        case .collectionNotFound: return "Collection not found"
        }
    }
}
