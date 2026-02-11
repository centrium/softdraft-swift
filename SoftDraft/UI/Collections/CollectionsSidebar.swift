//
//  CollectionsSidebar.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct CollectionsSidebar: View {
    let libraryURL: URL

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
                    List(selection: $listSelection) {
                        rows(selectionEnabled: true)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Collections")
            .focused($sidebarFocused)
            .onChange(of: selection.selectedCollectionID) { _, newValue in
                guard listSelection != newValue else { return }
                listSelection = newValue
                scheduleScrollToSelection(using: proxy, animated: true)
            }
            .onChange(of: listSelection) { _, newValue in
                guard selection.selectedCollectionID != newValue else { return }
                DispatchQueue.main.async {
                    selection.selectCollection(newValue)
                }
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
                SidebarRow {
                    Image(systemName: "tray")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("Inbox")
                        .font(.system(size: 14))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .help("Inbox is a built-in collection and can’t be renamed or deleted.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("Inbox")
                .listRowBackground(selectionBackground(for: "Inbox"))
                .listRowInsets(
                    EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                )
                .if(selectionEnabled) { view in
                    view.tag("Inbox")
                }

                Divider()
                    .listRowSeparator(.hidden)
            }

            ForEach(visibleCollections, id: \.self) { name in
                collectionRow(for: name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(name)
                    .listRowBackground(selectionBackground(for: name))
                    .listRowInsets(
                        EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                    )
                    .if(selectionEnabled) { view in
                        view.tag(name)
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
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))

                        Text(showAllCollections ? "Show less" : "Show more")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(top: 6, leading: 6, bottom: 10, trailing: 6)
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
            SidebarRow {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))

                Text(name)
                    .font(.system(size: 14))

                if libraryManager.mandatoryCollections.contains(name) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .help("Inbox is a built-in collection and can’t be renamed or deleted.")
                }
            }
        }
    }

    // MARK: - Selection Background

    private func selectionBackground(for name: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                selection.selectedCollectionID == name
                ? Color.primary.opacity(0.08)
                : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        selection.selectedCollectionID == name
                        ? Color.primary.opacity(0.12)
                        : .clear,
                        lineWidth: 0.5
                    )
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
                        ? Color.accentColor
                        : Color.secondary.opacity(0.35),
                        lineWidth: 1
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

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            content
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
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
