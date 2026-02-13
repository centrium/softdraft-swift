//
//  LibraryRailView.swift
//  SoftDraft
//
//  Created by Matt Adams on 31/01/2026.
//

import SwiftUI

struct LibraryRailView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var uiState: UIState
    @State private var tagSelection: String? = nil
    
    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private let sidebarSlotHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 0) {

                if uiState.sidebarMode == .collections {
                    CollectionsSidebar(libraryURL: libraryURL)
                        .padding(.horizontal, 6)
                        .padding(.top, 8)

                } else {
                    List(selection: $tagSelection) {
                        ForEach(libraryManager.allTagsSorted, id: \.id) { item in

                            let isSelected = tagSelection == item.id

                            HStack {
                                Text("#\(item.id)")
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(Color.primary.opacity(0.84))

                                Spacer()

                                Text("\(item.count)")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(Color.secondary.opacity(0.75))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .listRowBackground(Color.clear)
                            .listRowInsets(
                                EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                            )
                            .listRowSeparator(.hidden)
                            .tag(item.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)
                    .onChange(of: tagSelection) { _, newValue in
                        guard let newValue else { return }
                        if libraryManager.visibleTag != newValue {
                            libraryManager.selectTag(newValue)
                        }
                    }
                    .onAppear {
                        tagSelection = libraryManager.visibleTag
                    }
                    .onChange(of: libraryManager.visibleTag) { _, newValue in
                        tagSelection = newValue
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: sidebarSlotHeight)
            .padding(.bottom, 6)
            
            if let tag = libraryManager.visibleTag {
                HStack(spacing: 8) {
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        libraryManager.clearTagSelection()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            

            NotesListView(
                libraryURL: libraryURL,
                collection: selectedCollection
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
