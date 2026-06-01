import AppKit
import SwiftUI

/// Top chrome row that sits beneath the traffic lights in hidden-title-bar windows.
struct ShellTrafficLightStrip: View {
    var body: some View {
        Color.clear
            .frame(height: ShellLayout.toolbarHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.navigator)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.shellBorder)
                    .frame(height: 1)
            }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    var onWindowAttached: ((NSWindow) -> Void)?

    func makeNSView(context: Context) -> WindowSetupView {
        let view = WindowSetupView()
        view.onWindowAttached = onWindowAttached
        return view
    }

    func updateNSView(_ nsView: WindowSetupView, context: Context) {
        nsView.onWindowAttached = onWindowAttached
    }
}

final class WindowSetupView: NSView {
    var onWindowAttached: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        onWindowAttached?(window)
    }
}
