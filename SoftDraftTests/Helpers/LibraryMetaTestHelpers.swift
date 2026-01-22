import Foundation
import XCTest
@testable import SoftDraft

@MainActor
extension XCTestCase {
    @discardableResult
    func waitForMetaUpdate(
        in libraryURL: URL,
        timeout: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: @escaping (LibraryMeta) -> Bool
    ) async throws -> LibraryMeta {
        let deadline = Date().addingTimeInterval(timeout)
        var lastMeta = try LibraryMetaStore.load(libraryURL)

        while Date() < deadline {
            lastMeta = try LibraryMetaStore.load(libraryURL)
            if predicate(lastMeta) {
                return lastMeta
            }

            let nanos = UInt64(pollInterval * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanos)
        }

        XCTFail("Timed out waiting for library meta update", file: file, line: line)
        return lastMeta
    }
}
