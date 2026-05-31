# ADR-0001: Clean Architecture Boundaries

## Status

Accepted

## Context

TabGT will manage SSH sessions, local terminal processes, credentials, host-key
trust, snippets, and diagnostics. These parts have different security and
platform constraints, so direct coupling between SwiftUI and infrastructure
would make the app hard to test and evolve.

## Decision

Use Clean Architecture boundaries:

- Domain owns entities and protocols.
- Presentation owns SwiftUI and view models.
- Infrastructure implements SSH, terminal, PTY, and diagnostics adapters.
- App is the composition root.

## Consequences

- The first implementation can run with mocks.
- SwiftTerm, Citadel, Keychain, SwiftData, and PTY can be added independently.
- Unit tests can validate state and use cases without network or shells.
