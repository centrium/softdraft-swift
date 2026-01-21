# Repository Guidelines

## Project Structure & Module Organization
SoftDraft lives inside `SoftDraft/`: `App/` hosts `SoftDraftApp.swift` and command definitions, and `UI/` splits SwiftUI screens into `State/`, `Notes/`, `Commands/`, and `Collections/`. Core logic sits in `Core/` (`Collections/`, `Notes/`, `Meta/`, `Library/`, `AppConfig/`) and should stay platform-neutral; add new services beside their peers rather than inside UI. Assets belong in `SoftDraft/Assets.xcassets`. Tests mirror this layout in `SoftDraftTests/` with shared fixtures in `Helpers/TestLibrary.swift`.

## Build, Test, and Development Commands
- `scripts/ci.sh` runs the debug build plus tests, adds a release archive when `CI_ARCHIVE=true`, and accepts overrides like `DESTINATION="platform=macOS,arch=x86_64"`.
- `xed SoftDraft.xcodeproj` opens the workspace with the `SoftDraft` app and test targets available.
- `xcodebuild -scheme SoftDraft -configuration Debug -destination 'platform=macOS,arch=arm64' build` compiles the macOS app and surfaces warnings for CI.
- `xcodebuild -scheme SoftDraft -destination 'platform=macOS,arch=arm64' test` runs the XCTest suite headless; rerun after changing Core or UI logic.
- `xcodebuild -scheme SoftDraft -configuration Release -archivePath build/SoftDraft.xcarchive archive` produces a notarization-ready archive.

## Coding Style & Naming Conventions
Use Swift 5.9 defaults: four-space indentation, same-line braces, and trailing commas in multiline literals. Types stay PascalCase, extension files follow `Type+Capability.swift`, and functions use camelCase imperatives (`makeTempLibrary`). Favor structs for models, annotate reference types with `@MainActor` or `ObservableObject`, and limit each SwiftUI file to one screen or scene. Run Xcode’s Re-Indent command or `swiftformat` before committing.

## Testing Guidelines
Suites live under `SoftDraftTests`, aligned with the corresponding feature directory (e.g., note flows in `Notes/`). Build fixtures with `TestLibrary.makeTempLibrary()` so destructive operations never touch a real library. Name methods `testScenarioOutcome`, assert both disk changes and metadata updates, and add regression coverage whenever you fix bugs. Always run `xcodebuild -scheme SoftDraft -destination 'platform=macOS,arch=arm64' test` locally before pushing.

## Commit & Pull Request Guidelines
History favors short imperative subjects (`Initial Commit`), so keep summaries ≤50 characters and describe the change (“Fix pin migration”). Expand on intent, risks, and testing in the body, referencing issues via `Fixes #123` when relevant. Pull requests must outline the problem, solution, verification steps, and add screenshots or recordings for any UI-visible change.

## Security & Configuration Tips
`AppConfigStore` writes to `~/Library/Application Support/Softdraft/app-config.json`; never commit that path and avoid assuming it exists on other machines. Validate user-selected libraries through `LibraryValidator.ensureLibraryStructure` before reading or writing, and rely on the temp-library helper for manual experiments. Keep heavy file I/O inside detached tasks and publish back on the main actor to avoid UI hangs.
