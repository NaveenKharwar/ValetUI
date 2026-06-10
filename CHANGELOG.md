# Changelog

All notable changes to ValetUI are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
