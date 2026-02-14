//
//  Commands.swift
//  SoftDraft
//

import SwiftUI

struct LibraryCommands: Commands {

    @ObservedObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry

    init(libraryManager: LibraryManager) {
        self.libraryManager = libraryManager
    }

    var body: some Commands {

        // ───────── File / Library ─────────
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                commandRegistry.run("note.create")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.create"))
            
            Button("New Collection") {
                commandRegistry.run("collection.create")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("collection.create"))
            
            Button("Focus Mode") {
                commandRegistry.run("view.toggleZenMode")
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("view.toggleZenMode"))
            
            Button("Open Library…") {
                openLibrary()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Divider()

            Button("Rebuild Library Index") {
                commandRegistry.run("library.index.rebuild")
            }
            .disabled(!commandRegistry.canExecute("library.index.rebuild"))
        }
        
        // --------- Collection commands --------
        CommandMenu("Collections") {
            Button("New Note in Current Collection") {
                commandRegistry.run("note.createInCollection")
            }
            .disabled(!commandRegistry.canExecute("note.createInCollection"))

            Button("Expand Collections List") {
                commandRegistry.run("collection.list.expand")
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("collection.list.expand"))

            Button("Collapse Collections List") {
                commandRegistry.run("collection.list.collapse")
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("collection.list.collapse"))

            Button("Rename Current Collection…") {
                commandRegistry.run("collection.rename")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("collection.rename"))
            
            Button("Delete Current Collection") {
                commandRegistry.run("collection.delete")
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("collection.delete"))

            Button("Reveal Current Collection in Finder") {
                commandRegistry.run("collection.revealInFinder")
            }
            .disabled(!commandRegistry.canExecute("collection.revealInFinder"))
            
        }

        // ───────── Note commands ─────────
        CommandMenu("Note") {
            Button("Move Note…") {
                commandRegistry.run("note.move")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("note.move"))

            Button("Pin / Unpin") {
                commandRegistry.run("note.togglePin")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!commandRegistry.canExecute("note.togglePin"))

            Button("Duplicate Note") {
                commandRegistry.run("note.duplicate")
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.duplicate"))

            Button("Reveal Note in Finder") {
                commandRegistry.run("note.revealInFinder")
            }
            .disabled(!commandRegistry.canExecute("note.revealInFinder"))

            Menu("State") {
                let currentState = selectedNoteState
                Button {
                    commandRegistry.run("note.state.setDrafting")
                } label: {
                    if currentState == .drafting {
                        Label(NoteState.drafting.displayName, systemImage: "checkmark")
                    } else {
                        Text(NoteState.drafting.displayName)
                    }
                }
                .keyboardShortcut("1", modifiers: [.option])
                .disabled(!commandRegistry.canExecute("note.state.setDrafting"))

                Button {
                    commandRegistry.run("note.state.setRefining")
                } label: {
                    if currentState == .refining {
                        Label(NoteState.refining.displayName, systemImage: "checkmark")
                    } else {
                        Text(NoteState.refining.displayName)
                    }
                }
                .keyboardShortcut("2", modifiers: [.option])
                .disabled(!commandRegistry.canExecute("note.state.setRefining"))

                Button {
                    commandRegistry.run("note.state.setFinished")
                } label: {
                    if currentState == .finished {
                        Label(NoteState.finished.displayName, systemImage: "checkmark")
                    } else {
                        Text(NoteState.finished.displayName)
                    }
                }
                .keyboardShortcut("3", modifiers: [.option])
                .disabled(!commandRegistry.canExecute("note.state.setFinished"))
            }

            Button("Cycle State") {
                commandRegistry.run("note.state.cycle")
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("note.state.cycle"))

            Button("Cycle State Filter") {
                commandRegistry.run("note.stateFilter.cycle")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("note.stateFilter.cycle"))

            Button("Show All States") {
                commandRegistry.run("note.stateFilter.clear")
            }
            .disabled(!commandRegistry.canExecute("note.stateFilter.clear"))

            Button("Delete Note") {
                commandRegistry.run("note.delete")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!commandRegistry.canExecute("note.delete"))

            Button("Preview Note") {
                commandRegistry.run("view.togglePreviewMode")
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("view.togglePreviewMode"))
        }

        CommandMenu("Navigate") {
            Button("Focus Sidebar") {
                if libraryManager.activeLibraryURL != nil {
                    commandRegistry.run("sidebar.showCollections")
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("Focus Tags Sidebar") {
                commandRegistry.run("sidebar.showTags")
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("sidebar.showTags"))

            Button("Focus Editor") {
                commandRegistry.run("focus.editor")
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(!commandRegistry.canExecute("focus.editor"))

            Button("Focus Next Region") {
                commandRegistry.run("focus.cycle.forward")
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            Button("Focus Previous Region") {
                commandRegistry.run("focus.cycle.backward")
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
        }

        CommandMenu("Tags") {
            Button("Show Tagged Notes") {
                guard let tagID = libraryManager.visibleTag else { return }
                commandRegistry.run(
                    "tag.select",
                    arguments: CommandArguments(tagID: tagID)
                )
            }
            .disabled(
                !commandRegistry.canExecute(
                    "tag.select",
                    arguments: CommandArguments(tagID: libraryManager.visibleTag)
                )
            )

            Button("Remove Tag from Selected Note") {
                guard let tagID = libraryManager.visibleTag else { return }
                commandRegistry.run(
                    "tag.removeFromNote",
                    arguments: CommandArguments(
                        noteID: nil,
                        tagID: tagID
                    )
                )
            }
            .disabled(
                !commandRegistry.canExecute(
                    "tag.removeFromNote",
                    arguments: CommandArguments(
                        noteID: nil,
                        tagID: libraryManager.visibleTag
                    )
                )
            )
        }

        CommandMenu("Insert") {
            Button("Image…") {
                commandRegistry.run("note.insertImage.fromFile")
            }
            .disabled(!commandRegistry.canExecute("note.insertImage.fromFile"))
        }
    }

    private var selectedNoteState: NoteState? {
        guard let noteID = commandRegistry.context.selection.selectedNoteID else {
            return nil
        }
        return commandRegistry.context.libraryManager.libraryIndex?.notes[noteID]?.state ?? .drafting
    }

    private func openLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await libraryManager.setActiveLibrary(url)
            }
        }
    }
}
