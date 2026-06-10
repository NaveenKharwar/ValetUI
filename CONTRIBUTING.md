# Contributing to ValetUI

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Laravel Valet installed
- Homebrew

## Getting Started

1. Fork the repo and clone your fork
2. Open `ValetUI.xcodeproj` in Xcode
3. Set your Development Team in Signing & Capabilities
4. Build and run (`⌘R`)

## Branch Conventions

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases |
| `develop` | Integration branch |
| `feature/short-name` | New features |
| `fix/short-name` | Bug fixes |

## Pull Requests

- Target `develop` (not `main`)
- Keep PRs focused — one concern per PR
- Include a description of what changed and why
- Ensure the app builds with 0 warnings
- Test manually: launch the app, confirm the changed feature works

## Code Style

- Swift 6 strict concurrency throughout
- `@Observable` + `@MainActor` for ViewModels
- `actor` for any shared mutable state accessed from multiple tasks
- No `Process()` string interpolation — always use `arguments: [String]` array
- No UI code in ViewModels, no business logic in Views

## Reporting Bugs

Open a GitHub Issue with:
- macOS version
- Valet version (`valet --version`)
- PHP version (`php -v`)
- Steps to reproduce
- Expected vs actual behavior
