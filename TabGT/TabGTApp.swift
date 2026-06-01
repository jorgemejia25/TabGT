import AppKit
import SwiftUI

@main
struct TabGTApp: App {
    init() {
        // Askpass and key temp files are recreated on demand with stable paths.
        // Avoid deleting them here — SwiftUI can re-run App.init while sessions
        // are still alive in debug builds, leaving SSH_ASKPASS pointing at removed files.
        registerTerminationCleanup()
    }

    private func registerTerminationCleanup() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            SSHAskPassHelper.cleanup()
            SSHPrivateKeyHelper.cleanup()
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(windowRole: .main)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandMenu("Terminal") {
                Button("New Terminal") {
                    KeybindingActionRouter.shared.perform(.newTerminal)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    KeybindingActionRouter.shared.perform(.closeActiveTab)
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Move to New Window") {
                    KeybindingActionRouter.shared.perform(.moveToNewWindow)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Focus Tab 1") {
                    KeybindingActionRouter.shared.context.focusTabAtIndex(0)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Focus Tab 2") {
                    KeybindingActionRouter.shared.context.focusTabAtIndex(1)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Focus Tab 3") {
                    KeybindingActionRouter.shared.context.focusTabAtIndex(2)
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Split Right") {
                    KeybindingActionRouter.shared.perform(.splitRight)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("Split Down") {
                    KeybindingActionRouter.shared.perform(.splitDown)
                }
                .keyboardShortcut("\\", modifiers: [.command, .shift])

                Divider()

                Button("Close Group") {
                    KeybindingActionRouter.shared.perform(.closeActiveGroup)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Navigator") {
                    KeybindingActionRouter.shared.perform(.toggleNavigator)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Toggle Inspector") {
                    KeybindingActionRouter.shared.perform(.toggleInspector)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    KeybindingActionRouter.shared.perform(.openSettings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        WindowGroup(id: "detached", for: DetachedWindowPayload.self) { $payload in
            if let payload {
                ContentView(windowRole: .detached(payload))
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 900, height: 600)
    }
}
