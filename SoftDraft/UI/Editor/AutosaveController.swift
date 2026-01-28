//
//  AutosaveController.swift
//  SoftDraft
//
//  Created by Matt Adams on 24/01/2026.
//


import Foundation

@MainActor
final class AutosaveController {

    private var task: Task<Void, Never>?

    func schedule(
        delay: Duration = .milliseconds(800),
        action: @escaping @Sendable () async -> Void
    ) {
        task?.cancel()
        task = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
