//
//  AppConfigStore.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/AppConfig/AppConfigStore.swift

import Foundation

enum AppConfigStore {

    private static let fileName = "app-config.json"

    private static var configURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let dir = support.appendingPathComponent("Softdraft", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        return dir.appendingPathComponent(fileName)
    }

    static func load() async -> AppConfig {
        let url = configURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppConfig()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            // Corrupt config? Start fresh.
            return AppConfig()
        }
    }

    static func save(_ config: AppConfig) async {
        let url = configURL

        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Intentionally swallow errors:
            // config failure should never break the app
            assertionFailure("Failed to save AppConfig: \(error)")
        }
    }
}
