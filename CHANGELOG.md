# Changelog

All notable changes to TabGT will be documented in this file.

The format is based on Keep a Changelog, and this project uses semantic
versioning once stable release channels are established.

## [1.1.0] - 2026-05-31

### Added

- Workspace folder browser for local and SSH sessions.
- Directory path normalization for Unix, Windows, OSC 7, and file URLs.
- Detached terminal windows and cross-window tab movement.
- Inspector sections for workspace folders, Git status, and Claude Code state.
- Claude Code hook installation support and session activity tracking.
- Git prompt integration that reports branch, status, ahead/behind, and latest
  commit metadata.
- Snippet launch modes for running commands in the current tab or a copied new
  tab.
- Terminal paste handling tests for bracketed paste and PowerShell behavior.
- SSH private-key helper support for inline Keychain-backed keys.

### Changed

- Improved SSH launch commands with shell integration hooks for working
  directory, Git status, and Windows PowerShell sessions.
- Improved SSH connection diagnostics, retry handling, and reconnect state.
- Reworked workspace coordination so sessions can move across detached windows.
- Refined inspector layout, reorder behavior, and feature screens.

### Fixed

- Made askpass helper generation stable and more robust when temporary files are
  recreated.
- Isolated session view model tests from the shared workspace coordinator.

## [1.0.0] - 2026-05-31

### Added

- macOS SwiftUI terminal workspace.
- Local shell sessions through macOS PTY.
- SSH sessions through the system OpenSSH client.
- Connection profiles, groups, tags, startup folders, and remote shell settings.
- Tabbed and split terminal workspace layout.
- Command snippets with trigger-based expansion.
- Clip tray and terminal-output automation rules.
- Custom themes and configurable keybindings.
- Keychain-backed SSH password references.
- JSON-backed local repositories with restrictive file permissions.
- Open source project documentation, CI, Dependabot, and security policy.

### Security

- Release builds use Hardened Runtime.
- SSH passwords are read from Keychain through the askpass helper and are not
  written into temporary helper scripts.
- SSH username, host, and remote shell inputs are validated before launch.

### Distribution

- First public DMG build for manual installation by dragging `TabGT.app` into
  `/Applications`.
- This build is not notarized; macOS may require manual approval in Privacy &
  Security on first launch.
