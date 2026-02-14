//
//  LibraryManager+InternalWrites.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    // MARK: - Internal writes

    func beginInternalWrite(noteID: String? = nil) {
        internalWriteDepth &+= 1
        if let noteID {
            recordInternalWrite(noteID)
        }
    }

    func endInternalWrite(noteID: String? = nil) {
        internalWriteDepth = max(0, internalWriteDepth - 1)
        if let noteID {
            recordInternalWrite(noteID)
        }
    }

    var isPerformingInternalWrite: Bool {
        internalWriteDepth > 0
    }

    func suppressEvents(for noteID: String) {
        recordInternalWrite(noteID)
    }

    private func recordInternalWrite(_ noteID: String) {
        recentInternalWrites[noteID] = Date()
    }

    func cleanupInternalWrites() {
        guard !recentInternalWrites.isEmpty else { return }
        let threshold = Date().addingTimeInterval(-internalWriteCooldown)
        recentInternalWrites = recentInternalWrites.filter { _, timestamp in
            timestamp >= threshold
        }
    }

    func shouldIgnore(noteID: String) -> Bool {
        cleanupInternalWrites()
        guard let timestamp = recentInternalWrites[noteID] else { return false }
        return Date().timeIntervalSince(timestamp) < internalWriteCooldown
    }
}
