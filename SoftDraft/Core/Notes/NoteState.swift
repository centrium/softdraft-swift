//
//  NoteState.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import Foundation

enum NoteState: String, Codable, CaseIterable, Sendable {
    case drafting
    case refining
    case finished

    var displayName: String {
        switch self {
        case .drafting:
            return "Drafting"
        case .refining:
            return "Refining"
        case .finished:
            return "Finished"
        }
    }

    var next: NoteState {
        switch self {
        case .drafting:
            return .refining
        case .refining:
            return .finished
        case .finished:
            return .drafting
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""

        switch rawValue {
        case "drafting", "active":
            self = .drafting
        case "refining", "inReview":
            self = .refining
        case "finished", "completed":
            self = .finished
        default:
            self = .drafting
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
