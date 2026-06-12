# Changelog

All notable changes to ValetUI are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-12

### Added
- Per-site PHP isolation (`valet isolate`/`unisolate`) from the site menu; isolated version shown in the site row
- In-app log viewer: live tail of Valet/Nginx/PHP logs with auto-scroll, text selection, and Console.app handoff
- Share Publicly: opens a `valet share` tunnel in Terminal, with preflight checks for the configured share tool (ngrok/cloudflared binary present, Expose token configured)
- Subdomain reachability indicator (green/red dot per subdomain)
- Remove HTTPS action for secured subdomains (previously enable-only)
- New WordPress Site creator hardening: site names validated before reaching SQL, AppleScript, or Terminal commands
- Unit test suite (`ValetUITests`): parsers, site-name validation, log tailing, wp-config patching — runs in CI on every push
- PHP menu hint when only one version is installed, with the brew command to add more

### Changed
- Subdomains now ride Valet's native wildcard serving instead of custom Nginx configs (which pointed at a PHP socket Valet doesn't use and broke after PHP switches); tracked subdomains live in an app registry, legacy configs are migrated and cleaned up automatically
- Menu data refreshes on every menu open; background polling now only keeps the status icon fresh
- `AppViewModel` split into domain view models (`PHPViewModel`, `ServicesViewModel`); dead `SitesViewModel`/`SettingsViewModel` removed
- wp-config.php dynamic-URL fix writes a backup (`wp-config.php.valetui-backup`) before editing
- MySQL passwords passed via `MYSQL_PWD` environment variable instead of command-line arguments (visible in `ps`)
- Release pipeline ships an ad-hoc signed universal DMG (no Apple Developer account required); tests gate the release

### Fixed
- Shell commands producing >64KB of output no longer deadlock the app
- Shell execution no longer blocks a concurrency thread while waiting for process exit
- PHP switching dead-ended when the unversioned `php` formula was installed alongside a linked `php@X` — both menu items were marked current and disabled; the default formula's version is now read from its Cellar directory
- Intel Macs: hardcoded `/opt/homebrew` paths replaced with auto-detected Homebrew prefix (nginx check, `php -v`, log paths, PHP socket)
- "PHP current" placeholder leaking into the menu — real version number shown instead
- Securing a subdomain no longer deletes the Valet site symlink that a later `valet unsecure` needs
- Removing a site cleans up the certificate `.conf` file (previously leaked)

## [1.0.0] - 2025-06-09

### Added
- Menu bar icon with live Valet status indicator (green/red)
- Sites management: lists linked and parked Valet sites
- Per-site submenu: open in browser, open in Finder, copy URL, enable/disable HTTPS
- PHP version switcher via `valet use php@X.Y`
- Services management: restart Valet, Nginx, PHP-FPM, DNSMasq
- Logs quick-access: Valet, Nginx, PHP logs
- Settings: Launch at Login (ServiceManagement), Auto-refresh with configurable interval
- First-launch onboarding: detects missing Homebrew, Valet, or PHP
- Dark mode support (automatic via native macOS)
- GitHub Actions: build validation and release workflow with notarization template
