//
//  Debouncer.swift
//  SoftDraft
//
//  Created by Matt Adams on 25/01/2026.
//


// Debouncer.swift

import Foundation

@MainActor
final class Debouncer {

    private let delay: TimeInterval
    private var task: Task<Void, Never>?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func schedule(_ action: @escaping () -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                action()
            }
        }
    }
}