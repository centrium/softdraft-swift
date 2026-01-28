//
//  LibraryFilesystemWatcher.swift
//  SoftDraft
//
//  Created by ChatGPT on 05/02/2026.
//

import Foundation
import CoreServices

enum LibraryFilesystemEvent: Equatable {
    case added(noteID: String)
    case modified(noteID: String)
    case renamed(from: String, to: String)
    case deleted(noteID: String)
}

final class LibraryFilesystemWatcher {

    typealias EventHandler = @Sendable ([LibraryFilesystemEvent]) -> Void

    private struct SnapshotEntry {
        let noteID: String
        let modifiedAt: Date
        let fileIdentifier: UInt64?
    }

    private struct Snapshot {
        var entries: [String: SnapshotEntry] = [:]
        var identifiers: [UInt64: SnapshotEntry] = [:]

        static var empty: Snapshot { Snapshot() }
    }

    private let libraryURL: URL
    private let collectionsURL: URL
    private let debounceInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.softdraft.fs-watcher")
    private let handler: EventHandler

    private var stream: FSEventStreamRef?
    private var pendingWorkItem: DispatchWorkItem?
    private var snapshot: Snapshot = .empty

    init(
        libraryURL: URL,
        debounceInterval: TimeInterval = 0.35,
        handler: @escaping EventHandler
    ) {
        self.libraryURL = libraryURL
        self.collectionsURL = libraryURL.appendingPathComponent("collections")
        self.debounceInterval = debounceInterval
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        queue.async { [weak self] in
            guard let self, self.stream == nil else { return }
            self.snapshot = self.captureSnapshot()
            self.startStream()
        }
    }

    func stop() {
        queue.sync {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil

            if let stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
            }
            stream = nil
            snapshot = .empty
        }
    }

    func refreshBaseline() {
        queue.async { [weak self] in
            guard let self else { return }
            self.snapshot = self.captureSnapshot()
        }
    }

    private func startStream() {
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard FileManager.default.fileExists(atPath: collectionsURL.path) else {
            return
        }

        let paths = [collectionsURL.path] as CFArray

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.eventCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private static let eventCallback: FSEventStreamCallback = { _, context, _, _, _, _ in
        guard let context else { return }
        let watcher = Unmanaged<LibraryFilesystemWatcher>
            .fromOpaque(context)
            .takeUnretainedValue()
        watcher.scheduleScan()
    }

    private func scheduleScan() {
        pendingWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.performScan()
        }
        pendingWorkItem = workItem

        queue.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: workItem
        )
    }

    private func performScan() {
        let latest = captureSnapshot()
        let events = diffSnapshots(old: snapshot, new: latest)
        snapshot = latest

        guard !events.isEmpty else { return }
        handler(events)
    }

    private func captureSnapshot() -> Snapshot {
        guard FileManager.default.fileExists(atPath: collectionsURL.path) else {
            return .empty
        }

        let enumerator = FileManager.default.enumerator(
            at: collectionsURL,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileResourceIdentifierKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        )

        var entries: [String: SnapshotEntry] = [:]
        var identifierMap: [UInt64: SnapshotEntry] = [:]

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "md" else { continue }

            do {
                let values = try url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileResourceIdentifierKey,
                    .isRegularFileKey
                ])

                guard values.isRegularFile == true else { continue }

                let modified = values.contentModificationDate ?? Date()
                let identifier = values.fileResourceIdentifier.flatMap(Self.makeIdentifier)
                let noteID = relativePath(for: url)
                guard !noteID.isEmpty else { continue }

                let entry = SnapshotEntry(
                    noteID: noteID,
                    modifiedAt: modified,
                    fileIdentifier: identifier
                )

                entries[noteID] = entry
                if let identifier {
                    identifierMap[identifier] = entry
                }
            } catch {
                continue
            }
        }

        return Snapshot(entries: entries, identifiers: identifierMap)
    }

    private func diffSnapshots(
        old: Snapshot,
        new: Snapshot
    ) -> [LibraryFilesystemEvent] {

        var events: [LibraryFilesystemEvent] = []
        var consumedNewIDs = Set<String>()

        for (noteID, newEntry) in new.entries {
            if let oldEntry = old.entries[noteID],
               abs(newEntry.modifiedAt.timeIntervalSince(oldEntry.modifiedAt)) > 0.0005 {
                events.append(.modified(noteID: noteID))
                consumedNewIDs.insert(noteID)
            } else if old.entries[noteID] != nil {
                consumedNewIDs.insert(noteID)
            }
        }

        var consumedIdentifiers = Set<UInt64>()

        for (noteID, oldEntry) in old.entries where new.entries[noteID] == nil {
            if let identifier = oldEntry.fileIdentifier,
               let renamedEntry = new.identifiers[identifier] {
                events.append(.renamed(
                    from: noteID,
                    to: renamedEntry.noteID
                ))
                consumedNewIDs.insert(renamedEntry.noteID)
                consumedIdentifiers.insert(identifier)
            } else {
                events.append(.deleted(noteID: noteID))
            }
        }

        for (noteID, entry) in new.entries where !consumedNewIDs.contains(noteID) {
            if let identifier = entry.fileIdentifier,
               consumedIdentifiers.contains(identifier) {
                continue
            }
            events.append(.added(noteID: noteID))
        }

        return events
    }

    private func relativePath(for fileURL: URL) -> String {
        let basePath = collectionsURL.path
        var path = fileURL.path
        if path.hasPrefix(basePath) {
            path.removeFirst(basePath.count)
        }
        return path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func makeIdentifier(from value: Any) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }

        if let data = value as? Data,
           data.count >= MemoryLayout<UInt64>.size {
            return data.withUnsafeBytes { bytes in
                bytes.load(as: UInt64.self)
            }
        }

        return nil
    }
}
