//
//  NotePrefetchCache.swift
//  SoftDraft
//

import Foundation

actor NotePrefetchCache {

    static let shared = NotePrefetchCache()

    private var cachedContent: [String: String] = [:]
    private var inflightTasks: [String: Task<String?, Never>] = [:]

    func preload(
        libraryURL: URL,
        noteID: String
    ) {
        guard cachedContent[noteID] == nil else { return }
        guard inflightTasks[noteID] == nil else { return }

        inflightTasks[noteID] = Task.detached(priority: .userInitiated) {
            try? NoteStore.load(
                libraryURL: libraryURL,
                noteID: noteID
            )
        }
    }

    func consume(noteID: String) async -> String? {
        if let cached = cachedContent.removeValue(forKey: noteID) {
            return cached
        }

        guard let task = inflightTasks.removeValue(forKey: noteID) else { return nil }
        return await task.value ?? nil
    }

    func put(noteID: String, content: String) {
        cachedContent[noteID] = content
    }

    func clear(noteID: String) {
        inflightTasks.removeValue(forKey: noteID)?.cancel()
        cachedContent.removeValue(forKey: noteID)
    }

    func clearAll() {
        inflightTasks.values.forEach { $0.cancel() }
        inflightTasks.removeAll()
        cachedContent.removeAll()
    }
}
