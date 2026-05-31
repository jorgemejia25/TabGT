# Contributing

TabGT is early-stage. Keep changes small and aligned with the architecture.

## Guidelines

- Keep Domain independent from SwiftUI and third-party libraries.
- Put system and package integrations under Infrastructure.
- Use protocols for SSH, terminal transport, credentials, host keys, and local
  shells.
- Do not log passwords, private keys, passphrases, or raw secrets.
- Validate any string that reaches `ssh`, a shell, `Process`, file paths, or
  regular expressions.
- Store user data with restrictive local permissions.
- Add focused tests when changing session state, persistence, or security code.

## Development Flow

1. Build the macOS target.
2. Run unit tests.
3. Keep UI changes accessible and readable in dark mode.
4. Document architecture decisions under `Docs/Decisions` when they affect
   project direction.

## Before Opening a Pull Request

- Run `xcodebuild -scheme TabGT -destination 'platform=macOS' -only-testing:TabGTTests test`.
- Check `git status --short` for generated Xcode/macOS files.
- Do not include screenshots or fixtures containing real hosts, usernames,
  tokens, command history, or terminal output.
