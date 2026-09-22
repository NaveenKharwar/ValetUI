# Contributing to ValetUI

This file is the single source of truth for contributing to ValetUI. It is written to be useful to both human developers and AI coding agents. Read it fully before making changes.

---

## Requirements

- macOS 14.0+
- Xcode 15.0+ (macOS 15 runner in CI uses Xcode 16+, required for Swift 6)
- Laravel Valet installed
- Homebrew

## Getting Started

1. Fork the repo and clone your fork
2. Open `ValetUI.xcodeproj` in Xcode
3. Set your Development Team in Signing & Capabilities
4. Build and run (`⌘R`)

---

## Project Architecture

ValetUI is a macOS menu bar app. It has no external dependencies — Foundation, AppKit, and SwiftUI only.

### Directory Layout

```
ValetUI/
├── App/              # @main entry point, window scenes
├── Models/           # Plain value types (Site, PHPVersion, ServiceStatus, AppSettings…)
├── Services/         # System integration and business logic
├── Parsers/          # Pure, stateless output parsers (BrewParser, ServiceParser, ValetParser)
├── ViewModels/       # UI state — @Observable @MainActor classes
├── Views/            # SwiftUI views only, no logic
│   └── Preferences/  # Per-tab preference views
├── Utilities/        # AppConstants, LogTailer, extensions
└── Resources/        # Assets, Info.plist
ValetUITests/         # Unit tests — parsers, validators, patching
.github/workflows/    # build.yml, release.yml
```

### Layer Rules

| Layer | What goes here | What never goes here |
|---|---|---|
| **Models** | Plain structs/enums, `Sendable`, no side effects | Business logic, shell calls, UI |
| **Parsers** | Pure functions: `String → [Model]` | State, async, I/O |
| **Services** | Shell execution, filesystem writes, multi-step flows | SwiftUI types, `@State` |
| **ViewModels** | `@Observable @MainActor` state, calls Services/Parsers | UI code (NSAlert etc.) |
| **Views** | Layout, binding to ViewModel via `@Environment` | Business logic, shell calls |

### Data Flow

```
User action → View → ViewModel.someAction()
                           ↓
                  ShellCommandService.execute(...)
                           ↓
                  Parser.parse(output)
                           ↓
                  @Observable state updated → SwiftUI re-renders
```

Sites and certificates are read directly from `~/.config/valet/` via `ValetConfigReader` — no subprocess needed for this.

---

## Key Files

| File | Purpose |
|---|---|
| `App/ValetUIApp.swift` | `@main` entry point, `MenuBarExtra` scene, window scenes |
| `ViewModels/AppViewModel.swift` | Main orchestrator — owns `PHPViewModel` and `ServicesViewModel`, drives refresh |
| `Views/MenuContentView.swift` | Enum-based router between Sites / PHP / Logs panels |
| `Services/ShellCommandService.swift` | `actor` wrapping `Process()` — all shell calls go through here |
| `Services/ValetConfigReader.swift` | Reads `~/.config/valet/` directly, no subprocess |
| `Utilities/AppConstants.swift` | Path resolution with ARM/Intel fallbacks, MySQL socket detection |

---

## Naming Conventions

| Kind | Convention | Example |
|---|---|---|
| ViewModels | `*ViewModel` | `AppViewModel`, `PHPViewModel` |
| Services | `*Service` | `ShellCommandService`, `SubdomainService` |
| Parsers | `*Parser` | `BrewParser`, `ValetParser` |
| Views | `*View` | `SitesPanelView`, `AboutPrefsView` |
| Models | No suffix | `Site`, `PHPVersion`, `ServiceStatus` |
| Utilities | Descriptive | `AppConstants`, `LogTailer` |

---

## Concurrency Model

The project runs under **Swift 6 strict concurrency**. All new code must compile cleanly with no concurrency warnings.

- **`@Observable @MainActor`** — all ViewModels. State mutations happen on the main thread automatically.
- **`actor`** — `ShellCommandService` and `SubdomainService`. Serialises access to shared mutable state.
- **`async let`** — concurrent shell calls inside `AppViewModel.refresh()` (status + PHP + services run in parallel).
- **`AsyncStream`** — used in `ShellCommandService` to await process termination without blocking.
- **No `DispatchQueue.main.async`** — use `@MainActor` instead.
- **No `waitUntilExit()`** — use `terminationHandler` + `AsyncStream` to avoid blocking a concurrency thread.

---

## Shell Command Rules

All shell execution goes through `ShellCommandService.shared`. Never instantiate `Process()` directly in a ViewModel or View.

**Safe:**
```swift
await ShellCommandService.shared.execute(
    AppConstants.resolvedBrewPath,
    arguments: ["services", "list"]
)

// Passwords via environment, never argv
await ShellCommandService.shared.execute(
    AppConstants.resolvedMySQLPath,
    arguments: ["-u", dbUser, "-e", "DROP DATABASE IF EXISTS `\(dbName)`;"],
    extraEnvironment: ["MYSQL_PWD": dbPass]
)
```

**Forbidden:**
```swift
// ❌ String interpolation in arguments
Process().launchPath = "/bin/sh"
Process().arguments = ["-c", "brew services \(name)"]

// ❌ User input interpolated into any shell string
"valet link \(userInput)"
```

- Always use `arguments: [String]` — never build a shell string from user input.
- Never pass passwords on the command line — use `extraEnvironment`.
- For static pipelines with no user input, `executeShell("grep pattern /path")` is acceptable.

---

## Path Resolution

Never hardcode `/opt/homebrew` — Apple Silicon and Intel Macs use different prefixes. Use `AppConstants`:

```swift
AppConstants.resolvedBrewPath      // /opt/homebrew/bin/brew or /usr/local/bin/brew
AppConstants.homebrewPrefix        // /opt/homebrew or /usr/local
AppConstants.resolvedPHPPath       // derived from prefix
AppConstants.resolvedMySQLPath     // ARM-first, then Intel fallback
AppConstants.resolvedMySQLSocket   // searches common socket locations
AppConstants.mysqlSocketArgs       // ready-to-use -d arguments for PHP
```

If you need a new path that differs by architecture, add a computed property to `AppConstants` following the same fallback pattern.

---

## Security Patterns

These are non-negotiable:

- **Site name validation** — `Site.isValidName()` accepts only `[a-zA-Z0-9-_.]`. Validate before any shell call, SQL, or filesystem operation that uses a user-supplied name.
- **Database name validation** — `SiteDeleterService.isSafeDBName()` must pass before any `DROP DATABASE`. SQL identifiers are backtick-quoted.
- **Passwords in environment** — `MYSQL_PWD` env var, never argv (visible in `ps`).
- **Terminal commands** — written to a temp `.command` script and opened via `NSWorkspace`. No AppleScript, no string interpolation in shell commands.

---

## Adding New Features

### New shell-backed feature
1. Add the shell call inside an existing or new `*Service.swift` (not in a ViewModel).
2. Parse the output in a `*Parser.swift` if the output is structured (keep parsers pure).
3. Expose a method on the appropriate `*ViewModel.swift`.
4. Bind it in a View via `@Environment`.

### New multi-step operation
Follow the pattern in `WordPressInstallerService` and `SiteDeleterService`:
1. Define a `Step` enum (CaseIterable) with human-readable raw values.
2. Define a `StepState` enum (`pending, running, done, skipped, failed(String)`).
3. Two-phase design: `buildPlan()` (preflight) → `execute(plan:)` (destructive steps).
4. Publish `stepStates: [Step: StepState]` as `@Observable` state so the View can render progress.

### New preference tab
1. Create `Views/Preferences/*PrefsView.swift`.
2. Add the tab case to `PreferencesView.swift`.
3. Persist settings via `AppSettings` (UserDefaults-backed `@Observable` singleton in `Models/AppSettings.swift`).

### New path constant
Add a `static var resolved*Path` computed property to `AppConstants.swift` with ARM-first, Intel fallback pattern.

---

## Testing

Tests live in `ValetUITests/`. They run standalone — no app host, no simulator.

| Test File | What it covers |
|---|---|
| `BrewParserTests.swift` | PHP version parsing, edge cases |
| `ServiceParserTests.swift` | `brew services list` output parsing |
| `ValetParserTests.swift` | Valet links/parked output |
| `LogTailerTests.swift` | Large file tail, mid-line start |
| `SiteValidationTests.swift` | Injection character rejection |
| `WPConfigServiceTests.swift` | wp-config.php patching |

**Write tests for:**
- Any new Parser (pure function — trivial to test)
- Any new validator
- Any function that mutates files (use temp directories)

**Do not mock `ShellCommandService`** — if a test requires live shell execution, it is an integration test and belongs in a separate target or manual QA.

Run tests locally:
```bash
xcodebuild test \
  -project ValetUI.xcodeproj \
  -scheme ValetUI \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
```

---

## Branch Conventions

| Branch | Purpose |
|---|---|
| `main` | Stable releases |
| `develop` | Integration branch |
| `feature/short-name` | New features |
| `fix/short-name` | Bug fixes |

## Pull Requests

- Target `develop` (not `main`)
- One concern per PR
- Describe what changed and why
- Build must pass with 0 warnings
- Test manually: launch the app, confirm the changed feature works end-to-end

---

## CI Workflows

Two GitHub Actions workflows run automatically on `macos-15` (Xcode 16+, required for Swift 6).

### Build (`build.yml`)
Triggers on every push to `main`/`develop` and on PRs targeting `main`.

1. Build in **Debug** (no code signing)
2. Run **unit tests**
3. Build in **Release** (no code signing)

A failing step blocks merge. Never merge a red build.

### Release (`release.yml`)
Triggers only when a version tag (`v*`) is pushed.

1. Run unit tests — aborts if any fail
2. Stamp `Info.plist` with version from the tag, build number from commit count
3. **Archive** with ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) — no Apple Developer account required
4. **Create DMG** — `.app` + `/Applications` symlink, compressed with `hdiutil`
5. **Attach DMG** to the GitHub Release via `softprops/action-gh-release`

---

## Releasing a New Version

1. Update `CHANGELOG.md` — add a `## [X.Y.Z] - YYYY-MM-DD` section with `### Added / Changed / Fixed` entries
2. Bump `MARKETING_VERSION` in Xcode project settings (or directly in `project.pbxproj`) to match
3. Commit: `git commit -m "chore(release): bump version to X.Y.Z"`
4. Push to `main`
5. Tag and push:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
6. Release workflow runs, builds the DMG, attaches it to the GitHub Release

`Info.plist` uses `$(MARKETING_VERSION)` — changing it in the Xcode project is the only step needed. The About page reads it at runtime via `AppConstants.appVersion`.

## Release Notes

Release notes are **written manually** on GitHub when the tag is created or edited. The workflow only attaches the DMG — it does not generate or overwrite notes.

Copy the relevant `## [X.Y.Z]` block from `CHANGELOG.md` into the GitHub Release description verbatim.

---

## Reporting Bugs

Open a GitHub Issue with:
- macOS version
- Valet version (`valet --version`)
- PHP version (`php -v`)
- Steps to reproduce
- Expected vs actual behavior
