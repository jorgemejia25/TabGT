import AppKit
import SwiftUI

struct RootShellView: View {
    private let windowID: UUID

    @StateObject private var inputBridge: SessionInputBridge
    @StateObject private var snippets: SnippetsViewModel
    @EnvironmentObject private var connections: ConnectionsViewModel
    @StateObject private var terminalProfiles: TerminalProfilesViewModel
    @StateObject private var sessions: SessionsViewModel
    @StateObject private var automations: AutomationsViewModel
    @ObservedObject private var keybindings = KeybindingStore.shared

    @Environment(\.scenePhase) private var scenePhase

    @State private var destination: RootDestination = .terminal
    @State private var isNavigatorVisible = true
    @State private var isInspectorVisible = true
    @State private var connectionEditorPresentation: ConnectionEditorPresentation?
    @State private var isLocalProfileEditorPresented = false
    @State private var isNewProfileTypePresented = false
    @State private var pendingNewProfileKind: NewProfileKind?
    @State private var isSSHImportPresented = false
    @State private var editingLocalProfile: LocalTerminalProfile?

    @AppStorage("tabgt.navigatorWidth") private var navigatorWidth: Double = 240
    @AppStorage("tabgt.inspectorWidth") private var inspectorWidth: Double = 300

    init(windowID: UUID = UUID()) {
        self.windowID = windowID

        let bridge = SessionInputBridge()
        let automations = AutomationsViewModel.live()
        let sessions = SessionsViewModel(windowID: windowID, isMain: true, coordinator: .shared)
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

            HStack(spacing: 0) {
                if isNavigatorVisible {
                    NavigatorSidebar(
                        connections: connections,
                        terminalProfiles: terminalProfiles,
                        destination: $destination,
                        onOpenHost: { host, folder in
                            sessions.openSSHSession(for: host, workingDirectory: folder)
                        },
                        onOpenLocalProfile: { profile, folder in
                            sessions.openLocalSession(profile: profile, workingDirectory: folder)
                        },
                        onEditHost: { host in
                            connectionEditorPresentation = .edit(host)
                        },
                        onDeleteHost: { host in
                            connections.delete(host.id)
                        },
                        onEditLocalProfile: { profile in
                            editingLocalProfile = profile
                            isLocalProfileEditorPresented = true
                        },
                        onNewProfile: {
                            isNewProfileTypePresented = true
                        }
                    )
                    .frame(width: navigatorWidth)
                    .overlay(alignment: .trailing) {
                        ShellPanelResizeGrip(
                            edge: .navigatorTrailing,
                            panelWidth: navigatorWidthBinding,
                            minWidth: 180,
                            maxWidth: 380
                        )
                        .offset(x: ShellPanelResizeGrip.edgeOffset)
                    }
                }

                VStack(spacing: 0) {
                    AppToolbar(
                        sessions: sessions,
                        sidebarVisible: isNavigatorVisible,
                        isNavigatorVisible: $isNavigatorVisible,
                        isInspectorVisible: $isInspectorVisible,
                        onOpenSettings: { destination = .settings }
                    )

                    destinationContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .top)
        }
        .ignoresSafeArea(.all, edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(host: connections.selectedHost, session: sessions.selectedSession)
        }
        .background {
            WindowConfigurator { window in
                KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: window)
            }
        }
        .background {
            KeybindingEventMonitor(
                store: keybindings,
                context: keybindingActionContext,
                isEnabled: { !isKeybindingSheetPresented }
            )
        }
        .onAppear {
            KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: NSApp.keyWindow)
            snippets.wireLaunchDependencies(
                sessions: sessions,
                connections: connections,
                terminalProfiles: terminalProfiles
            )
        }
        .onDisappear {
            if let window = NSApp.keyWindow {
                KeybindingActionRouter.shared.removeContext(for: window)
            }
        }
        .onChange(of: keybindingActionContextVersion) { _, _ in
            KeybindingActionRouter.shared.updateContext(keybindingActionContext, for: NSApp.keyWindow)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                connections.flushToDisk()
            }
        }
        .sheet(isPresented: $isNewProfileTypePresented, onDismiss: presentPendingProfileEditor) {
            NewProfileTypeSheet(
                onSelectSSH: {
                    pendingNewProfileKind = .ssh
                    isNewProfileTypePresented = false
                },
                onSelectLocal: {
                    pendingNewProfileKind = .local
                    isNewProfileTypePresented = false
                }
            )
        }
        .sheet(item: $connectionEditorPresentation) { presentation in
            ConnectionEditorSheet(
                host: presentation.host,
                hosts: connections.hosts,
                onSave: { connections.save($0) },
                onDelete: { connections.delete($0) },
                onImportSSHConfig: {
                    connectionEditorPresentation = nil
                    isSSHImportPresented = true
                }
            )
        }
        .sheet(isPresented: $isLocalProfileEditorPresented) {
            TerminalProfileEditorSheet(
                profile: editingLocalProfile,
                onSave: { terminalProfiles.save($0) }
            )
            .id(editingLocalProfile?.id)
        }
        .sheet(isPresented: $isSSHImportPresented) { SSHConfigImportView() }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .terminal:
            HStack(spacing: 0) {
                WorkspaceView(
                    connections: connections,
                    sessions: sessions,
                    terminalProfiles: terminalProfiles,
                    snippets: snippets,
                    inputBridge: inputBridge
                )
                .environmentObject(automations)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isInspectorVisible {
                    InspectorPanel(
                        host: connections.selectedHost,
                        session: sessions.selectedSession,
                        connections: connections,
                        terminalProfiles: terminalProfiles,
                        automations: automations,
                        snippets: snippets,
                        inputBridge: inputBridge,
                        sessions: sessions,
                        onEditHost: { host in
                            connectionEditorPresentation = .edit(host)
                        },
                        onDeleteHost: { host in
                            connections.delete(host.id)
                        },
                        onEditLocalProfile: { profile in
                            editingLocalProfile = profile
                            isLocalProfileEditorPresented = true
                        }
                    )
                    .frame(width: inspectorWidth)
                    .overlay(alignment: .leading) {
                        ShellPanelResizeGrip(
                            edge: .inspectorLeading,
                            panelWidth: inspectorWidthBinding,
                            minWidth: 240,
                            maxWidth: 480
                        )
                        .offset(x: -ShellPanelResizeGrip.edgeOffset)
                    }
                }
            }

        case .snippets:
            SnippetsScreen(
                viewModel: snippets,
                session: sessions.selectedSession,
                profileContext: activeSnippetProfileContext
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .automations:
            AutomationsScreen(
                automations: automations,
                snippets: snippets
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .settings:
            SettingsView(
                onManageLocalProfiles: {
                    destination = .terminal
                    editingLocalProfile = nil
                    isLocalProfileEditorPresented = true
                },
                isModal: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var activeSnippetProfileContext: SnippetProfileContext? {
        guard let session = sessions.selectedSession else { return nil }
        return snippets.profileContext(for: session)
    }

    private var navigatorWidthBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(navigatorWidth) },
            set: { navigatorWidth = Double($0) }
        )
    }

    private var inspectorWidthBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(inspectorWidth) },
            set: { inspectorWidth = Double($0) }
        )
    }

    private func presentPendingProfileEditor() {
        switch pendingNewProfileKind {
        case .ssh:
            connectionEditorPresentation = .new
        case .local:
            editingLocalProfile = nil
            isLocalProfileEditorPresented = true
        case nil:
            break
        }
        pendingNewProfileKind = nil
    }

    private var isKeybindingSheetPresented: Bool {
        isNewProfileTypePresented
            || connectionEditorPresentation != nil
            || isLocalProfileEditorPresented
            || isSSHImportPresented
    }

    private var keybindingActionContextVersion: Int {
        var hasher = Hasher()
        hasher.combine(isNavigatorVisible)
        hasher.combine(isInspectorVisible)
        hasher.combine(destination)
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
            toggleNavigator: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isNavigatorVisible.toggle()
                }
            },
            toggleInspector: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isInspectorVisible.toggle()
                }
            },
            closeActiveGroup: {
                sessions.closeGroup(sessions.layout.focusedGroupID)
            },
            openSettings: {
                destination = .settings
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

private enum NewProfileKind {
    case ssh
    case local
}

private struct ConnectionEditorPresentation: Identifiable {
    let id: UUID
    let host: SSHHost?

    static var new: ConnectionEditorPresentation {
        ConnectionEditorPresentation(id: UUID(), host: nil)
    }

    static func edit(_ host: SSHHost) -> ConnectionEditorPresentation {
        ConnectionEditorPresentation(id: host.id, host: host)
    }
}
