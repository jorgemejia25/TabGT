# Privacy

TabGT does not include telemetry, analytics, crash reporting, or remote logging.

## Data Stored Locally

TabGT stores app data under `~/Library/Application Support/TabGT/`:

- SSH and local profile metadata.
- Command snippets.
- Automation rules.
- Captured clip tray values.
- Keybinding overrides.
- Custom themes.

Passwords are stored in Keychain. Private keys are referenced by path and are not
copied into TabGT storage.

## Sensitive Workflows

Local shells, SSH sessions, snippets, and automation captures can expose
sensitive data. Automation rules that read terminal output may persist values
such as URLs, identifiers, paths, hostnames, or command output in the clip tray.

Review clip tray contents before sharing logs, screenshots, bug reports, or
configuration files.
