# Changelog

All notable changes to TabGT will be documented in this file.

The format is based on Keep a Changelog, and this project uses semantic
versioning once stable release channels are established.

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
