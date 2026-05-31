# TabGT

TabGT is a macOS-first terminal workspace for local shells, SSH sessions,
snippets, themes, keybindings, and lightweight terminal automations.

The app is built with SwiftUI and follows Clean Architecture boundaries: the
presentation layer owns UI and view models, while SSH, terminal emulation,
local PTY execution, persistence, and credential storage live behind focused
domain contracts.

> TabGT is early-stage software. Review the security and privacy notes before
> using it with production systems or sensitive terminals.

## Features

- Local shell sessions through macOS PTY.
- SSH sessions through the system OpenSSH client.
- Connection groups, tags, startup folders, and remote shell preferences.
- Tabs and split panes for multi-session terminal workspaces.
- Command snippets with trigger-based expansion.
- Clip tray and automation rules for capturing terminal output.
- Custom themes and configurable keybindings.
- Keychain-backed SSH password references.
- JSON-backed local settings with restrictive file permissions.

## Project Status

TabGT is pre-release and under active development. The current codebase includes
real local shell and SSH execution, but APIs, storage formats, UI behavior, and
security controls may still change before stable releases.

Known security posture:

- Passwords are stored in macOS Keychain.
- SSH private keys are referenced by path and are not copied into app storage.
- SSH host-key trust is handled by the system OpenSSH `known_hosts` flow.
- Release builds enable Hardened Runtime.
- The macOS app sandbox is currently disabled because terminal workflows need
  broad process and file-system behavior.

See [SECURITY.md](SECURITY.md) and [PRIVACY.md](PRIVACY.md) for details.

## Requirements

- macOS with Xcode installed.
- Xcode support for the project's configured macOS SDK and deployment target.
- Swift Package Manager, provided by Xcode.
- System OpenSSH at `/usr/bin/ssh` for SSH sessions.

The current Xcode project is configured with a macOS `26.5` deployment target.
If you need to support older macOS versions, review the project settings and
test the app on those systems before distributing builds.

## Getting Started

Clone the repository:

```sh
git clone https://github.com/jorgemejia25/TabGT.git
cd TabGT
```

Open the project in Xcode:

```sh
open TabGT.xcodeproj
```

Select the `TabGT` scheme and run the macOS app target.

You can also build from the command line:

```sh
xcodebuild -project TabGT.xcodeproj -scheme TabGT -destination 'platform=macOS' build
```

Run unit tests:

```sh
xcodebuild -project TabGT.xcodeproj -scheme TabGT -destination 'platform=macOS' -only-testing:TabGTTests test
```

## Architecture

TabGT keeps platform and package integrations separate from core behavior.

- `TabGT/App`: app composition and environment setup.
- `TabGT/Core`: domain models, protocols, services, persistence helpers, and
  repositories.
- `TabGT/Infrastructure`: SwiftTerm, OpenSSH, Keychain, PTY, keybinding, and
  mock adapters.
- `TabGT/Features`: feature-specific SwiftUI views and view models.
- `TabGT/DesignSystem`: shared visual components and app styling.
- `TabGT/Root`: root shell, workspace, sidebars, toolbar, inspector, and
  settings.
- `TabGT/Resources`: bundled default resources and preview data.
- `TabGTTests`: focused unit tests for state, persistence, security, and core
  behavior.

For more detail, read [Docs/Architecture.md](Docs/Architecture.md) and
[Docs/Decisions/ADR-0001-clean-architecture.md](Docs/Decisions/ADR-0001-clean-architecture.md).

## Local Data

TabGT stores user data under:

```text
~/Library/Application Support/TabGT/
```

Current storage includes:

- `profiles/`: local terminal profiles and SSH profile metadata.
- `snippets/`: command snippets.
- `automations/`: automation rules.
- `clip-tray/`: captured terminal values.
- `keybindings.json`: shortcut overrides.
- `themes/`: custom themes.

Local app data is written with restrictive permissions where supported.
Passwords are stored in Keychain. Private keys stay wherever the user keeps
them and are referenced by path only.

## Security Notes

TabGT operates on sensitive surfaces:

- Local shells can run commands on your machine.
- SSH sessions can access remote systems.
- Snippets can insert or run shell commands.
- Automation rules can read terminal output and persist captured values.
- Screenshots, logs, fixtures, and bug reports may accidentally expose hostnames,
  usernames, commands, paths, tokens, or terminal output.

Do not commit real credentials, private keys, production hostnames, terminal
transcripts, or screenshots containing sensitive information.

Report vulnerabilities privately when possible. See [SECURITY.md](SECURITY.md).

## Dependencies

TabGT uses Swift Package Manager dependencies pinned in:

```text
TabGT.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Current third-party packages:

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- [swift-argument-parser](https://github.com/apple/swift-argument-parser)

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Sample Files

The repository includes sample resources for contributors and users:

- `SampleKeybindings/default-keybindings.json`
- `SampleThemes/soft-light.json`
- `SampleThemes/midnight-blue.json`

Review these files before importing or adapting them into your local setup.

## Contributing

Contributions are welcome while the project is still taking shape. Keep changes
small, testable, and aligned with the existing architecture.

Before opening a pull request:

```sh
xcodebuild -project TabGT.xcodeproj -scheme TabGT -destination 'platform=macOS' -only-testing:TabGTTests test
```

Also check that generated macOS/Xcode files and local secrets are not included:

```sh
git status --short
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) for project guidelines.

## License

TabGT is released under the MIT License. See [LICENSE](LICENSE).
