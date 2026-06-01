import SwiftUI

enum AppWindowRole {
    case main
    case detached(DetachedWindowPayload)
}

struct ContentView: View {
    var windowRole: AppWindowRole = .main

    @ObservedObject private var coordinator = WorkspaceCoordinator.shared
    @StateObject private var themeStore = ThemeStore.shared
    @StateObject private var terminalFontSettings = TerminalFontSettings.shared
    @StateObject private var inspectorLayout = InspectorLayoutStore.shared
    @State private var isShowingLaunchSplash = true

    var body: some View {
        Group {
            switch windowRole {
            case .main:
                RootView()
            case .detached(let payload):
                DetachedShellView(payload: payload)
            }
        }
        .environmentObject(ConnectionsViewModel.shared)
        .environmentObject(coordinator)
        .environmentObject(themeStore)
        .environmentObject(terminalFontSettings)
        .preferredColorScheme(themeStore.theme.appearance.colorScheme)
        .id(themeStore.selectedThemeID)
        .modifier(LaunchSplashIfNeeded(isPresented: $isShowingLaunchSplash, windowRole: windowRole))
        .background {
            WindowSceneBridge()
        }
    }
}

private struct WindowSceneBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                WorkspaceCoordinator.shared.configureWindowOpening { payload in
                    openWindow(id: "detached", value: payload)
                }
            }
    }
}

private struct LaunchSplashIfNeeded: ViewModifier {
    @Binding var isPresented: Bool
    var windowRole: AppWindowRole

    func body(content: Content) -> some View {
        switch windowRole {
        case .main:
            content.launchSplash(isPresented: $isPresented)
        case .detached:
            content
        }
    }
}
