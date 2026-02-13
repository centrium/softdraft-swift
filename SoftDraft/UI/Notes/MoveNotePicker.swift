//
//  MoveNotePicker.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
//

import SwiftUI

struct MoveNoteSheet: View {

    let currentCollection: String
    let noteCount: Int
    let collections: [String]
    let onMove: (String) -> Void
    let onCancel: () -> Void

    @State private var query: String = ""
    @State private var selectedDestination: String? = nil
    @FocusState private var searchFieldFocused: Bool

    private var selectableCollections: [String] {
        filteredCollections.filter { $0 != currentCollection }
    }

    private var filteredCollections: [String] {
        let ordered = collections.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ordered }

        return ordered.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var moveButtonDisabled: Bool {
        selectedDestination == nil || selectedDestination == currentCollection
    }

    private var subtitle: String {
        noteCount == 1
        ? "Currently in \(currentCollection)"
        : "\(noteCount) notes selected. Current collection: \(currentCollection)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Move note")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Search collections", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFieldFocused)
                .onChange(of: query) { _, _ in
                    if let selectedDestination,
                       !selectableCollections.contains(selectedDestination) {
                        self.selectedDestination = nil
                    }
                }
                .onSubmit {
                    confirmMoveIfPossible()
                }

            List(filteredCollections, id: \.self, selection: $selectedDestination) { name in
                Text(name)
                    .foregroundStyle(name == currentCollection ? .secondary : .primary)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                    .disabled(name == currentCollection)
                    .tag(name)
            }
            .listStyle(.plain)
            .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Move") {
                    confirmMoveIfPossible()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(moveButtonDisabled)
            }
        }
        .padding(20)
        .frame(minWidth: 440)
        .onAppear {
            searchFieldFocused = true
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .downArrow {
                moveSelection(.down)
                return .handled
            }
            if keyPress.key == .upArrow {
                moveSelection(.up)
                return .handled
            }
            if keyPress.key == .escape {
                onCancel()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if confirmMoveIfPossible() {
                return .handled
            }
            return .ignored
        }
        .onExitCommand {
            onCancel()
        }
        .interactiveDismissDisabled()
    }

    @discardableResult
    private func confirmMoveIfPossible() -> Bool {
        guard
            let selectedDestination,
            selectedDestination != currentCollection
        else { return false }
        onMove(selectedDestination)
        return true
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !selectableCollections.isEmpty else { return }
        let ids = selectableCollections
        let currentIndex = selectedDestination.flatMap { ids.firstIndex(of: $0) }

        let nextIndex: Int
        switch direction {
        case .down:
            if let currentIndex {
                nextIndex = min(currentIndex + 1, ids.count - 1)
            } else {
                nextIndex = 0
            }
        case .up:
            if let currentIndex {
                nextIndex = max(currentIndex - 1, 0)
            } else {
                nextIndex = ids.count - 1
            }
        default:
            return
        }

        selectedDestination = ids[nextIndex]
    }
}
