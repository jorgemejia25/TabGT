import SwiftUI

struct ContentView: View {
    @StateObject private var themeStore = ThemeStore.shared
    @StateObject private var terminalFontSettings = TerminalFontSettings.shared
    @State private var isShowingLaunchSplash = true

    var body: some View {
        RootView()
            .environmentObject(ConnectionsViewModel.shared)
            .environmentObject(themeStore)
            .environmentObject(terminalFontSettings)
            .preferredColorScheme(themeStore.theme.appearance.colorScheme)
            .id(themeStore.selectedThemeID)
            .launchSplash(isPresented: $isShowingLaunchSplash)
    }
}
