//
//  UniqueFileName.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum UniqueFilename {

    static func ensure(
        in directory: URL,
        base: String
    ) -> String {

        let fm = FileManager.default
        var attempt = 0

        while true {
            let name = attempt == 0
                ? "\(base).md"
                : "\(base)-\(attempt).md"

            let path = directory.appendingPathComponent(name)

            if !fm.fileExists(atPath: path.path) {
                return name
            }

            attempt += 1
        }
    }
}
