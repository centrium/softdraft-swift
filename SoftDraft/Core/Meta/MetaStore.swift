//
//  MetaStore.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum MetaStore {

    private static let filename = "meta.json"

    static func load(libraryURL: URL) -> Meta {
        let url = libraryURL.appendingPathComponent(filename)

        guard
            let data = try? Data(contentsOf: url),
            let meta = try? JSONDecoder().decode(Meta.self, from: data)
        else {
            return Meta()
        }

        return meta
    }

    static func save(
        libraryURL: URL,
        meta: Meta
    ) throws {
        let url = libraryURL.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(meta)

        try data.write(to: url, options: [.atomic])
    }
}
