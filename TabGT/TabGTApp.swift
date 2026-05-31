import SwiftUI

@main
struct TabGTApp: App {
    init() {
        SSHAskPassHelper.cleanup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
    }
}
