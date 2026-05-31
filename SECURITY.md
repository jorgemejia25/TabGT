# Security Policy

TabGT handles sensitive connection data. Treat credential and host-key handling
as security-critical.

## Supported Versions

TabGT is pre-release. Security fixes are applied to `main` until versioned
releases exist.

## Rules

- Store passwords and passphrases only in Keychain.
- Do not commit private keys or real credentials.
- Do not print secrets to logs, previews, screenshots, or test fixtures.
- Use the system OpenSSH `known_hosts` flow for SSH host-key trust.
- Keep mock data fake and clearly non-production.
- Treat snippets, local shells, remote shells, and terminal-output captures as
  command-execution or data-capture surfaces.

## Sensitive Data

SSH profile metadata, snippets, automation rules, and captured clips are stored
under `~/Library/Application Support/TabGT/` with restrictive local permissions.
Passwords are stored in Keychain. Private keys are referenced by path only.

## Reporting

Use private vulnerability reporting on the repository host when available. If it
is unavailable, open a public issue with only a high-level description and do
not include secret material, exploit details, private keys, passwords, hostnames,
or terminal transcripts.
