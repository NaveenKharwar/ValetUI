# ValetUI

A native macOS menu bar app for [Laravel Valet](https://laravel.com/docs/valet) — manage your local development environments without opening Terminal.

![Menu bar icon](https://github.com/user-attachments/assets/4b23eb3d-14fe-4474-a1d5-256f4673dd75)

## Features

- **Live status** — green/red indicator shows whether Valet is running
- **Sites management** — lists all linked and parked sites; open in browser, Finder, copy URL, toggle HTTPS
- **PHP switcher** — detects installed Homebrew PHP versions, switch with one click
- **Per-site PHP** — isolate a site to a specific PHP version (`valet isolate`) from the site menu
- **Subdomain manager** — Valet serves any subdomain natively; ValetUI tracks yours, enables per-subdomain HTTPS, checks reachability, and fixes WordPress URL handling (with automatic wp-config.php backup)
- **Share publicly** — one click opens a tunnel via `valet share` (ngrok, cloudflared, or Expose), with preflight checks for missing tools or tokens
- **Services control** — restart Valet, Nginx, PHP-FPM, DNSMasq
- **Log viewer** — live in-app tail of Valet/Nginx/PHP logs, with one-click Console.app handoff
- **WordPress site creator** — scaffold a full local WordPress install (directory, database, wp-config, admin user) via WP-CLI
- **Launch at Login** — via native ServiceManagement (no helper bundle)
- **Always fresh** — data refreshes every time the menu opens; optional background polling for the status icon
- **Onboarding** — detects missing Homebrew, Valet, or PHP with setup links
- **Dark mode** — automatic, native macOS appearance

Works on Apple Silicon and Intel Macs (Homebrew prefix auto-detected).

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 14.0 (Sonoma)+ |
| Xcode | 15.0+ (to build from source) |
| Laravel Valet | 3.x+ |
| Homebrew | Any recent version |

## Prerequisites

Before launching ValetUI, install the required tools. Open Terminal and run each block — skip any you already have.

### Required — Valet (any project type)

**1. Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. PHP**
```bash
brew install php
```

**3. Composer + Laravel Valet**
```bash
brew install composer
echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
composer global require laravel/valet
valet install
```

---

### Optional — WordPress sites only

ValetUI can create and manage WordPress sites. You need these two additional tools:

**4. MySQL**
```bash
brew install mysql
brew services start mysql
```

**5. WP-CLI**
```bash
brew install wp-cli
```

Once installed, open ValetUI and click **Check Again** in the menu — it will confirm everything is ready.

---

### Optional — public sharing

`valet share` needs a tunnel tool configured once. Pick one:

```bash
# Cloudflare quick tunnels — no account needed
brew install cloudflared && valet share-tool cloudflared

# or ngrok
brew install ngrok && valet share-tool ngrok

# or Expose (requires a free expose.dev account + token)
composer global require beyondcode/expose
expose token <YOUR-TOKEN>
valet share-tool expose
```

---

## Installation

### Build from Source

```bash
git clone https://github.com/naveenkharwar/ValetUI.git
cd ValetUI
open ValetUI.xcodeproj
```

In Xcode:
1. Select your Development Team in **Signing & Capabilities**
2. Press `⌘R` to build and run

### Download Release

Download the latest `.dmg` from [GitHub Releases](https://github.com/naveenkharwar/ValetUI/releases), open it, and drag **ValetUI** to **Applications**.

Releases are ad-hoc signed (free open-source build, not notarized by Apple), so macOS shows a one-time warning on first launch:

- **macOS 15 (Sequoia)+** — open the app once, dismiss the warning, then **System Settings → Privacy & Security → Open Anyway**
- **macOS 14 and earlier** — right-click the app → **Open** → **Open**
- Or from Terminal: `xattr -d com.apple.quarantine /Applications/ValetUI.app`

## Build Instructions

```bash
# Debug build (no signing)
xcodebuild build \
  -project ValetUI.xcodeproj \
  -scheme ValetUI \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

# Release archive
xcodebuild archive \
  -project ValetUI.xcodeproj \
  -scheme ValetUI \
  -configuration Release \
  -archivePath ./build/ValetUI.xcarchive
```

## Testing

```bash
xcodebuild test \
  -project ValetUI.xcodeproj \
  -scheme ValetUI \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The `ValetUITests` target is a standalone unit-test bundle (no app host, runs unsigned in CI). It covers the parsers (`BrewParser`, `ServiceParser`, `ValetParser`), site-name validation, log tailing, and the wp-config.php patcher. CI runs the suite on every push and PR — see `.github/workflows/build.yml`.

## Distribution (macOS App Signing)

1. **Sign**: Set your Apple Developer Team ID in Xcode or `DEVELOPMENT_TEAM` env var
2. **Archive**: `Product > Archive` in Xcode
3. **Notarize**: Use `xcrun notarytool` with your App Store Connect API key
4. **Staple**: `xcrun stapler staple ValetUI.app`
5. **DMG**: `hdiutil create -volname "ValetUI" -srcfolder ValetUI.app -format UDZO ValetUI.dmg`

See `.github/workflows/release.yml` for the full automated pipeline.

## Architecture

```
ValetUI/
├── App/            @main entry, MenuBarExtra + window scenes
├── Models/         Plain Swift value types (Site, PHPVersion, …)
├── Services/       ShellCommandService (actor), ValetConfigReader,
│                   SubdomainService, WPConfigService, installers
├── Parsers/        ValetParser, BrewParser, ServiceParser (pure, tested)
├── ViewModels/     AppViewModel (status, sites, orchestration) +
│                   PHPViewModel / ServicesViewModel (domain state & actions)
├── Views/          SwiftUI menu views, log viewer, subdomain manager
└── Utilities/      Constants, LogTailer, extensions
ValetUITests/       Standalone unit-test bundle
```

- **Shell execution**: `Process()` with explicit `executableURL` + `arguments` array — no shell injection risk; pipes drained concurrently and exit awaited via `terminationHandler` (no 64KB pipe deadlock, no blocked threads)
- **Defense in depth**: site names validated (`Site.isValidName`) before reaching SQL identifiers, AppleScript, or Terminal commands; MySQL passwords passed via `MYSQL_PWD` env var, never argv
- **Read, don't shell**: Valet state (sites, TLD, certs, PHP isolation) comes from `~/.config/valet/` files directly — subprocesses only where unavoidable
- **Subdomains**: Valet serves them natively (DnsMasq wildcard + server.php fallback) — ValetUI keeps a registry in Application Support and adds HTTPS, reachability checks, and WordPress URL fixes on top
- **sudo-required commands** (`valet secure/unsecure/isolate/share`): opened in Terminal via AppleScript — the app never asks for your password
- **Concurrency**: Swift 6 strict mode; `actor` for shell service, `@Observable @MainActor` for all UI state
- **Refresh model**: on every menu open, plus optional background polling for the status icon
- **Launch at Login**: `SMAppService.mainApp` (ServiceManagement framework, macOS 13+)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
