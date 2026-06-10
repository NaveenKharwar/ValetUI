# ValetUI

A native macOS menu bar app for [Laravel Valet](https://laravel.com/docs/valet) — manage your local development environments without opening Terminal.

![Menu bar icon](https://github.com/user-attachments/assets/4b23eb3d-14fe-4474-a1d5-256f4673dd75)

## Features

- **Live status** — green/red indicator shows whether Valet is running
- **Sites management** — lists all linked and parked sites; open in browser, Finder, copy URL, toggle HTTPS
- **PHP switcher** — detects installed Homebrew PHP versions, switch with one click
- **Services control** — restart Valet, Nginx, PHP-FPM, DNSMasq
- **Quick log access** — open Valet/Nginx/PHP logs in Console.app
- **Launch at Login** — via native ServiceManagement (no helper bundle)
- **Auto-refresh** — background polling at 5s / 15s / 30s / 1m intervals
- **Onboarding** — detects missing Homebrew, Valet, or PHP with setup links
- **Dark mode** — automatic, native macOS appearance

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

### Download Release (coming soon)

Download the latest `.dmg` from [GitHub Releases](https://github.com/naveenkharwar/ValetUI/releases).

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
├── App/            @main entry, MenuBarExtra scene
├── Models/         Plain Swift value types (Site, PHPVersion, …)
├── Services/       ShellCommandService (actor), LaunchAtLoginService
├── Parsers/        ValetParser, BrewParser, ServiceParser
├── ViewModels/     @Observable @MainActor classes
├── Views/          SwiftUI menu views
└── Utilities/      Constants, extensions
```

- **Shell execution**: `Process()` with explicit `executableURL` + `arguments` array — no shell injection risk
- **Concurrency**: Swift 6 strict mode; `actor` for shell service, `@MainActor` for all UI state
- **Auto-refresh**: `Task` + `Task.sleep` loop (no `Timer` retain cycle issues)
- **Launch at Login**: `SMAppService.mainApp` (ServiceManagement framework, macOS 13+)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
