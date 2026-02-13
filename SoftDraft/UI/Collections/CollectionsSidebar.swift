//
//  CollectionsSidebar.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct CollectionsSidebar: View {
    let libraryURL: URL

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var commandRegistry: CommandRegistry

    @State private var listSelection: String? = nil
    @State private var showAllCollections = false

    @FocusState private var renameFieldFocused: Bool
    @FocusState private var sidebarFocused: Bool

    private let collapsedLimit = 5

    private var isRenaming: Bool {
        selection.pendingCollectionRename != nil
    }
    
    private func syncSelectionFromModel() {
        guard let selected = selection.selectedCollectionID else { return }

        // Only update if List doesn't already match
        if listSelection != selected {
            listSelection = selected
        }
    }

    private func scrollToSelection(
        using proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard let selected = selection.selectedCollectionID else { return }
        guard selected == "Inbox" || visibleCollections.contains(selected) else {
            return
        }

        let action = {
            proxy.scrollTo(selected, anchor: .center)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                action()
            }
        } else {
            action()
        }
    }

    private func scheduleScrollToSelection(
        using proxy: ScrollViewProxy,
        animated: Bool
    ) {
        DispatchQueue.main.async {
            scrollToSelection(using: proxy, animated: animated)
        }
    }

    private var keyboardNavigableCollections: [String] {
        var ids: [String] = []
        if libraryManager.visibleCollections.contains("Inbox") {
            ids.append("Inbox")
        }
        ids.append(contentsOf: visibleCollections)
        return ids
    }

    private func handleCollectionMoveCommand(
        _ direction: MoveCommandDirection,
        using proxy: ScrollViewProxy
    ) {
        guard !isRenaming else { return }
        let ids = keyboardNavigableCollections
        guard !ids.isEmpty else { return }

        let current = selection.selectedCollectionID
        let currentIndex = current.flatMap { ids.firstIndex(of: $0) }
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

        let target = ids[nextIndex]
        guard target != current else { return }
        DispatchQueue.main.async {
            selection.selectCollection(target)
            listSelection = target
            scheduleScrollToSelection(using: proxy, animated: true)
        }
    }

    // MARK: - Ordering

    private var orderedCollections: [String] {
        let all = libraryManager.visibleCollections
        let nonInbox = all.filter { $0 != "Inbox" }
        return nonInbox.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var visibleCollections: [String] {
        let all = orderedCollections

        if showAllCollections {
            return all
        }

        var visible = Array(all.prefix(collapsedLimit))

        if
            let selected = selection.selectedCollectionID,
            !visible.contains(selected),
            all.contains(selected)
        {
            visible.append(selected)
        }

        return visible
    }

    // MARK: - View

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if isRenaming {
                    List {
                        rows(selectionEnabled: false)
                    }
                } else {
                    List {
                        rows(selectionEnabled: true)
                    }
                }
            }
            .listStyle(.sidebar)
            .focusable()
            .focusEffectDisabled()
            .navigationTitle("Collections")
            .focused($sidebarFocused)
            .onMoveCommand { direction in
                handleCollectionMoveCommand(direction, using: proxy)
            }
            .onKeyPress(phases: .down) { keyPress in
                if keyPress.key == .downArrow {
                    handleCollectionMoveCommand(.down, using: proxy)
                    return .handled
                }
                if keyPress.key == .upArrow {
                    handleCollectionMoveCommand(.up, using: proxy)
                    return .handled
                }
                return .ignored
            }
            .onChange(of: selection.selectedCollectionID) { _, newValue in
                guard listSelection != newValue else { return }
                listSelection = newValue
                scheduleScrollToSelection(using: proxy, animated: true)
            }
            .onChange(of: libraryManager.visibleCollections) { _, _ in
                // Re-apply selection once collections are available.
                DispatchQueue.main.async {
                    syncSelectionFromModel()
                    scheduleScrollToSelection(using: proxy, animated: false)
                }
            }
            .onChange(of: showAllCollections) { _, _ in
                scheduleScrollToSelection(using: proxy, animated: true)
            }
            .onAppear {
                syncSelectionFromModel()
                scheduleScrollToSelection(using: proxy, animated: false)
            }
            .onKeyPress(.return) {
                guard
                    sidebarFocused,
                    selection.selectedCollectionID != nil,
                    selection.pendingCollectionRename == nil
                else {
                    return .ignored
                }

                commandRegistry.run("collection.rename.begin")
                return .handled
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rows(selectionEnabled: Bool) -> some View {

        Section {
            if libraryManager.visibleCollections.contains("Inbox") {
                let isSelected = selection.selectedCollectionID == "Inbox"
                SidebarRow(
                    accentColor: SidebarAccentPalette.collections,
                    accentOpacity: isSelected
                        ? SidebarAccentPalette.selectedStripOpacity
                        : SidebarAccentPalette.stripOpacity
                ) {
                    Text("Inbox")
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(Color.primary.opacity(0.84))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("Inbox")
                .listRowBackground(selectionBackground(for: "Inbox"))
                .listRowInsets(
                    EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                )
                .if(selectionEnabled) { view in
                    view.onTapGesture {
                        sidebarFocused = true
                        guard selection.selectedCollectionID != "Inbox" else { return }
                        selection.selectCollection("Inbox")
                        listSelection = "Inbox"
                    }
                }
            }

            ForEach(visibleCollections, id: \.self) { name in
                collectionRow(for: name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(name)
                    .listRowBackground(selectionBackground(for: name))
                    .listRowInsets(
                        EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                    )
                    .if(selectionEnabled) { view in
                        view.onTapGesture {
                            sidebarFocused = true
                            guard selection.selectedCollectionID != name else { return }
                            selection.selectCollection(name)
                            listSelection = name
                        }
                    }
            }

            // Show more / less row
            if orderedCollections.count > collapsedLimit {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showAllCollections.toggle()
                    }
                } label: {
                    SidebarRow {
                        Text(showAllCollections ? "Show less" : "Show more")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 4, bottom: 6, trailing: 4)
                )
            }

        }
    }

    // MARK: - Collection Row

    @ViewBuilder
    private func collectionRow(for name: String) -> some View {
        if selection.pendingCollectionRename?.originalID == name {
            renameField
                .onAppear { renameFieldFocused = true }
        } else {
            let isSelected = selection.selectedCollectionID == name
            SidebarRow(
                accentColor: SidebarAccentPalette.collections,
                accentOpacity: isSelected
                    ? SidebarAccentPalette.selectedStripOpacity
                    : SidebarAccentPalette.stripOpacity
            ) {
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.primary.opacity(0.84))
            }
        }
    }

    // MARK: - Selection Background

    private func selectionBackground(for name: String) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                selection.selectedCollectionID == name
                ? Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
                : .clear
            )
    }

    // MARK: - Rename Field

    private var renameField: some View {
        TextField("", text: $selection.collectionRenameDraft)
            .textFieldStyle(.plain)
            .focused($renameFieldFocused)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        renameFieldFocused
                        ? Color.primary.opacity(0.2)
                        : Color.primary.opacity(0.12),
                        lineWidth: 0.7
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture { renameFieldFocused = true }
            .onSubmit { commandRegistry.run("collection.rename.confirm") }
            .onExitCommand { commandRegistry.run("collection.rename.cancel") }
    }
}

// MARK: - Shared Sidebar Row

struct SidebarRow<Content: View>: View {
    let content: Content
    let accentColor: Color?
    let accentOpacity: Double

    init(
        accentColor: Color? = nil,
        accentOpacity: Double = SidebarAccentPalette.stripOpacity,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.accentOpacity = accentOpacity
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let accentColor {
                Rectangle()
                    .fill(accentColor.opacity(accentOpacity))
                    .frame(width: SidebarAccentPalette.stripWidth)
                    .padding(.vertical, 2)
            }
            content
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Conditional Modifier Helper

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
