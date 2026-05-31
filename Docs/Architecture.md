# TabGT Architecture

TabGT is macOS-first and uses Clean Architecture boundaries from the first
iteration. SwiftUI owns presentation only. SSH, terminal emulation, local PTY,
Keychain, and persistence stay behind protocols.

## Layers

- App: composition root, app lifecycle, dependency wiring.
- Presentation: SwiftUI views, view models, navigation, Liquid Glass design.
- Domain: entities, session state, use cases, and protocol contracts.
- Data: repositories, SwiftData models, Keychain storage, host-key storage.
- Infrastructure: Citadel SSH, SwiftTerm, macOS PTY, network diagnostics.

## Dependency Rule

Dependencies point inward. Domain does not import SwiftUI, SwiftData, Citadel,
SwiftTerm, or platform terminal APIs. Infrastructure conforms to Domain
protocols, and App wires concrete implementations into Presentation.

## First Slice

The first slice ships a navigable mock workspace. It validates layout,
state ownership, session selection, and extension points before binding to real
SSH or local shell processes.

## Workspace Layout

The terminal workspace is modeled as a recursive layout tree. A node is either
a terminal group with its own tabs, or a split with two child nodes. This allows
nested VS Code-style terminal splits while keeping terminal sessions independent
from their visual placement.

Session state remains global in the session view model; groups only reference
session identifiers and own tab selection. Closing or moving a tab updates the
layout first, then removes unreferenced mock sessions.
