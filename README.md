# ValetUI

A native macOS menu bar app for [Laravel Valet](https://laravel.com/docs/valet) — manage your local development environments without opening Terminal.

## Screenshots

**Main panel** — floating card window with live Valet status, PHP version, and site count

![Main panel](https://github.com/user-attachments/assets/42d81a00-2593-4640-b06f-366ada1345b9)

**Site actions** — expand any site to reveal grouped Open / Manage / Danger action cards

![Site expanded](https://github.com/user-attachments/assets/41946e1b-9486-4646-98cf-83ab9650afd2)

**PHP panel** — switch versions with one click; hints for installing more

![PHP panel](https://github.com/user-attachments/assets/25140cef-f4de-4989-8eb8-05da858f384b)

**Preferences** — terminal and editor picker with live confirmation feedback

![Preferences](https://github.com/user-attachments/assets/302d08bd-66db-42e7-89fc-c66e9a8da87c)

**About** — app icon, version, and links

![About](https://github.com/user-attachments/assets/ad0d1fc1-da1e-438b-8b10-390147a8527b)

## Features

- **Live status** — green/red dot on the menu bar icon shows Valet state at a glance
- **Floating panel** — card-based window with a header showing PHP version, site count, and Valet status
- **Sites** — all linked and parked sites in one list; expand any site for grouped actions (Open, Manage, Danger)
- **Per-site actions** — open in browser, editor, terminal, or Finder; copy URL; share publicly; manage subdomains; toggle HTTPS; switch PHP version; delete
- **PHP switcher** — lists installed Homebrew PHP versions; switch with one click; hints for installing more
- **Per-site PHP isolation** — pin any site to a specific PHP version (`valet isolate`) without leaving the app
- **Subdomain manager** — per-subdomain HTTPS, reachability checks, and WordPress URL auto-fix (wp-config.php patched with backup)
- **Share publicly** — opens a `valet share` tunnel (ngrok, cloudflared, or Expose) in a new terminal window; preflight checks catch missing tools or tokens before opening
- **Services** — restart Valet, Nginx, PHP-FPM, DNSMasq individually or all at once
- **Log viewer** — live tail of Valet/Nginx/PHP logs in-app, with Console.app handoff
- **WordPress creator** — scaffold a full local WordPress install (directory, database, wp-config, admin user) via WP-CLI
- **WordPress one-click login** — "Login as Admin" button on any WordPress site opens the browser already logged in to wp-admin; "Copy Login URL" copies the link for testing in any browser; tokens are one-time-use and expire after 2 minutes
- **Terminal auto-discovery** — finds iTerm2, Warp, Ghostty, Alacritty, WezTerm, Kitty, and more wherever installed; always opens a new window
- **Preferences** — set default terminal and editor; each picker shows instant confirmation ("Default terminal is set to iTerm2")
- **About** — version, copyright, check for updates, and link to source
- **Launch at Login** — native ServiceManagement, no helper bundle
- **Auto-refresh** — panel refreshes on every open; optional background polling keeps the status dot current
- **Onboarding** — detects missing Homebrew, Valet, or PHP with setup instructions
- **Dark mode** — automatic, native macOS appearance

Works on Apple Silicon and Intel Macs (Homebrew prefix auto-detected).

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 14.0 (Sonoma)+ |
| Xcode | 16.0+ (to build from source — Swift 6) |
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
├── Views/          SwiftUI panel views (floating window UI), log viewer, subdomain manager
└── Utilities/      Constants, LogTailer, extensions
ValetUITests/       Standalone unit-test bundle
```

- **Shell execution**: `Process()` with explicit `executableURL` + `arguments` array — no shell injection risk; pipes drained concurrently and exit awaited via `terminationHandler` (no 64KB pipe deadlock, no blocked threads)
- **Defense in depth**: site names validated (`Site.isValidName`) before reaching SQL identifiers, AppleScript, or Terminal commands; MySQL passwords passed via `MYSQL_PWD` env var, never argv
- **Read, don't shell**: Valet state (sites, TLD, certs, PHP isolation) comes from `~/.config/valet/` files directly — subprocesses only where unavoidable
- **Subdomains**: Valet serves them natively (DnsMasq wildcard + server.php fallback) — ValetUI keeps a registry in Application Support and adds HTTPS, reachability checks, and WordPress URL fixes on top
- **sudo-required commands** (`valet secure/unsecure/isolate/share`): opened in a new terminal window via `NSWorkspace` + a temp `.command` script — no AppleScript, no escaping issues, works with any terminal
- **Concurrency**: Swift 6 strict mode; `actor` for shell service, `@Observable @MainActor` for all UI state
- **Refresh model**: on every menu open, plus optional background polling for the status icon
- **Launch at Login**: `SMAppService.mainApp` (ServiceManagement framework, macOS 13+)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
