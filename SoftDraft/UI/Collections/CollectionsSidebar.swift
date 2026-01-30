//
//  CollectionsSidebar.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

//
//  CollectionsSidebar.swift
//  SoftDraft
//

import SwiftUI

struct CollectionsSidebar: View {
    let libraryURL: URL

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var commandRegistry: CommandRegistry

    @State private var listSelection: String? = nil
    @FocusState private var renameFieldFocused: Bool
    @FocusState private var sidebarFocused: Bool


    private var isRenaming: Bool { selection.pendingCollectionRename != nil }

    var body: some View {
        Group {
            if isRenaming {
                // ✅ Non-selectable list while renaming
                List {
                    rows(selectionEnabled: false)
                }
            } else {
                // ✅ Normal selectable list when not renaming
                List(selection: $listSelection) {
                    rows(selectionEnabled: true)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Collections")
        .focused($sidebarFocused)
        .onAppear {
            listSelection = selection.selectedCollectionID
        }
        .onChange(of: selection.selectedCollectionID) { _, newValue in
            guard listSelection != newValue else { return }
            listSelection = newValue
        }
        .onChange(of: listSelection) { _, newValue in
            guard selection.selectedCollectionID != newValue else { return }
            DispatchQueue.main.async {
                selection.selectCollection(newValue)
            }
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

    @ViewBuilder
    private func rows(selectionEnabled: Bool) -> some View {
        
        Section {
            ForEach(libraryManager.visibleCollections, id: \.self) { name in
                collectionRow(for: name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .if(selectionEnabled) { view in
                        view.tag(name) // only tag rows when selection is enabled
                    }
            }
         } header: {
             Text("Collections")
                 .font(.caption)
                 .foregroundColor(.secondary)
                 .textCase(.uppercase)
                 .padding(.leading, 2)
         }
    }

    @ViewBuilder
    private func collectionRow(for name: String) -> some View {
        if selection.pendingCollectionRename?.originalID == name {
            renameField
                .onAppear { renameFieldFocused = true }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text(name)

                if libraryManager.mandatoryCollections.contains(name) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .help("Inbox is a built-in collection and can’t be renamed or deleted.")
                }
            }
        }
    }
    private var renameField: some View {
        TextField("", text: $selection.collectionRenameDraft)
            .textFieldStyle(.plain)
            .focused($renameFieldFocused)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(renameFieldFocused ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { renameFieldFocused = true } // click anywhere in the box focuses
            .onSubmit { commandRegistry.run("collection.rename.confirm") }
            .onExitCommand { commandRegistry.run("collection.rename.cancel") }
    }
}

// Small helper to conditionally apply a modifier without duplicating code
private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
