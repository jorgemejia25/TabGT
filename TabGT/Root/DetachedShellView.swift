import AppKit
import SwiftUI

struct DetachedShellView: View {
    let payload: DetachedWindowPayload

    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject private var connections: ConnectionsViewModel
    @ObservedObject private var keybindings = KeybindingStore.shared

    @StateObject private var inputBridge: SessionInputBridge
    @StateObject private var snippets: SnippetsViewModel
    @StateObject private var terminalProfiles: TerminalProfilesViewModel
    @StateObject private var sessions: SessionsViewModel
    @StateObject private var automations: AutomationsViewModel

    init(payload: DetachedWindowPayload) {
        self.payload = payload

        let bridge = SessionInputBridge()
        let automations = AutomationsViewModel.live()
        let sessions = SessionsViewModel(
            windowID: payload.windowID,
            isMain: false,
            coordinator: .shared
        )
        sessions.wireAutomations(automations)

        _inputBridge = StateObject(wrappedValue: bridge)
        _snippets = StateObject(wrappedValue: SnippetsViewModel.live(inputBridge: bridge))
        _terminalProfiles = StateObject(wrappedValue: TerminalProfilesViewModel.live())
        _sessions = StateObject(wrappedValue: sessions)
        _automations = StateObject(wrappedValue: automations)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 0) {
                ShellTrafficLightStrip()

                WorkspaceView(
                    connections: connections,
                    sessions: sessions,
                    terminalProfiles: terminalProfiles,
                    snippets: snippets,
                    inputBridge: inputBridge
                )
                .environmentObject(automations)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(host: connections.selectedHost, session: sessions.selectedSession)
        }
        .background {
            WindowConfigurator { window in
                KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: window)
                WorkspaceCoordinator.shared.registerCloseHandler(for: payload.windowID) {
                    dismissWindow()
                }
            }
        }
        .background {
            KeybindingEventMonitor(
                store: keybindings,
                context: keybindingActionContext,
                isEnabled: { true }
            )
        }
        .onAppear {
            sessions.syncLayoutFromCoordinator()
            sessions.focusGroup(payload.focusedGroupID)
            KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: NSApp.keyWindow)
            snippets.wireLaunchDependencies(
                sessions: sessions,
                connections: connections,
                terminalProfiles: terminalProfiles
            )
        }
        .onDisappear {
            WorkspaceCoordinator.shared.unregisterCloseHandler(for: payload.windowID)
            if let window = NSApp.keyWindow {
                KeybindingActionRouter.shared.removeContext(for: window)
            }
        }
        .onChange(of: keybindingActionContextVersion) { _, _ in
            KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: NSApp.keyWindow)
        }
    }

    private var keybindingActionContextVersion: Int {
        var hasher = Hasher()
        hasher.combine(sessions.layout.focusedGroupID)
        hasher.combine(sessions.layout.root.groups().map(\.selectedSessionID))
        return hasher.finalize()
    }

    private var keybindingActionContext: KeybindingActionContext {
        KeybindingActionContext(
            newTerminal: {
                if let profile = terminalProfiles.defaultProfile {
                    sessions.openLocalSession(profile: profile)
                } else {
                    sessions.openLocalSession()
                }
            },
            closeActiveTab: {
                guard let group = sessions.layout.root.group(id: sessions.layout.focusedGroupID),
                      let sessionID = group.selectedSessionID else {
                    return
                }
                sessions.close(sessionID, in: group.id)
            },
            splitRight: {
                sessions.splitGroup(sessions.layout.focusedGroupID, placement: .right)
            },
            splitDown: {
                sessions.splitGroup(sessions.layout.focusedGroupID, placement: .down)
            },
            closeActiveGroup: {
                sessions.closeGroup(sessions.layout.focusedGroupID)
            },
            moveToNewWindow: {
                guard let group = sessions.layout.root.group(id: sessions.layout.focusedGroupID),
                      let sessionID = group.selectedSessionID else {
                    return
                }
                sessions.detachTab(sessionID: sessionID, from: group.id)
            },
            focusTabAtIndex: { index in
                sessions.selectTab(at: index)
            }
        )
    }
}
