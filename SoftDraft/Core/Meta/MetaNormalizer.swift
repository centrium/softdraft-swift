//
//  MetaNormalizer.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import Foundation

enum MetaNormalizer {

    static func afterCollectionRename(
        meta: Meta,
        oldName: String,
        newName: String
    ) -> Meta {

        var next = meta
        var updated: [String: Bool] = [:]

        for (key, value) in meta.pinned {
            if key.hasPrefix("\(oldName)/") {
                let rest = key.dropFirst(oldName.count + 1)
                updated["\(newName)/\(rest)"] = value
            } else {
                updated[key] = value
            }
        }

        next.pinned = updated
        return next
    }

    static func afterCollectionDelete(
        meta: Meta,
        collection: String
    ) -> Meta {

        var next = meta
        next.pinned = meta.pinned.filter {
            !$0.key.hasPrefix("\(collection)/")
        }
        return next
    }
}
