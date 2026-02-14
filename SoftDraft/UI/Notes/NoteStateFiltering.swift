//
//  NoteStateFiltering.swift
//  SoftDraft
//

import Foundation

enum NoteStateFiltering {

    static func filteredNotes(
        from notes: [NoteSummary],
        stateFilter: NoteState?
    ) -> [NoteSummary] {
        guard let stateFilter else { return notes }
        return notes.filter { $0.state == stateFilter }
    }

    static func filteredByState<T>(
        _ values: [T],
        stateFilter: NoteState?,
        state: (T) -> NoteState
    ) -> [T] {
        guard let stateFilter else { return values }
        return values.filter { state($0) == stateFilter }
    }

    static func nextFilter(after current: NoteState?) -> NoteState? {
        switch current {
        case nil:
            return .drafting
        case .drafting:
            return .refining
        case .refining:
            return .finished
        case .finished:
            return nil
        }
    }
}
