import AppKit
import SwiftTerm
import SwiftUI

struct SSHTerminalView: View {
    var session: TerminalSession
    var host: SSHHost
    var launchConfig: SSHLaunchConfig
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @EnvironmentObject private var terminalFontSettings: TerminalFontSettings
    @EnvironmentObject private var automations: AutomationsViewModel

    var body: some View {
        SSHTerminalNSViewRepresentable(
            sessionID: session.id,
            host: host,
            launchConfig: launchConfig,
            sessions: sessions,
            snippets: snippets,
            inputBridge: inputBridge,
            fontSettings: terminalFontSettings,
            automations: automations
        )
        .background(TerminalTheme.background)
    }
}

private struct SSHTerminalNSViewRepresentable: NSViewRepresentable {
    var sessionID: UUID
    var host: SSHHost
    var launchConfig: SSHLaunchConfig
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @ObservedObject var fontSettings: TerminalFontSettings
    @ObservedObject var automations: AutomationsViewModel

    func makeCoordinator() -> SSHSessionCoordinator {
        SSHSessionCoordinator(sessionID: sessionID, host: host, sessions: sessions)
    }

    func makeNSView(context: Context) -> TerminalSurfaceHostView {
        let surfaceHost = TerminalSurfaceHostView()
        let terminal = resolveTerminal(context: context)
        surfaceHost.host(terminal)
        return surfaceHost
    }

    func updateNSView(_ nsView: TerminalSurfaceHostView, context: Context) {
        let terminal = resolveTerminal(context: context)
        nsView.host(terminal)

        guard let request = inputBridge.latestRequest,
              request.sessionID == sessionID,
              request.id != context.coordinator.lastRequestID else { return }

        context.coordinator.lastRequestID = request.id
        terminal.insertText(request.text, submit: request.submit)
    }

    static func dismantleNSView(_ nsView: TerminalSurfaceHostView, coordinator: SSHSessionCoordinator) {
        nsView.detachHostedTerminal()
    }

    private func resolveTerminal(context: Context) -> TabGTTerminalView {
        let terminal: TabGTTerminalView
        if let cached = TerminalViewPool.shared.view(for: sessionID) {
            terminal = cached
        } else {
            let view = TabGTTerminalView(frame: .zero)
            view.focusRingType = .none
            view.launchProcess(
                executable: SSHConfigBuilder.sshPath,
                args: launchConfig.args,
                extraEnvironment: launchConfig.extraEnvironment
            )
            TerminalViewPool.shared.store(view, for: sessionID)
            terminal = view
        }

        terminal.processDelegate = context.coordinator
        terminal.snippetProvider = { snippets.snippets }
        terminal.outputCallback = makeOutputCallback()
        terminal.connectionOutputCallback = { text in
            Task { @MainActor in
                context.coordinator.processConnectionOutput(text)
            }
        }
        terminal.applyTabGTKeyboardSettings()
        applyTheme(to: terminal)
        applyFont(to: terminal)
        context.coordinator.terminalView = terminal
        context.coordinator.publishInitialGeometry(from: terminal)
        return terminal
    }

    private func makeOutputCallback() -> (String) -> Void {
        let automationsRef = automations
        let sessionsRef = sessions
        let sid = sessionID
        return { text in
            Task { @MainActor in
                let title = sessionsRef.session(for: sid)?.title ?? "SSH"
                let clips = AutomationCaptureEngine.processText(
                    text,
                    rules: automationsRef.rules,
                    source: .terminalOutput,
                    sessionTitle: title
                )
                clips.forEach { automationsRef.addCapturedClip($0) }
            }
        }
    }

    @MainActor
    private func applyTheme(to view: TabGTTerminalView) {
        let t = AppTheme.current
        view.nativeBackgroundColor = NSColor(t.terminalBackground)
        view.nativeForegroundColor = NSColor(t.terminalForeground)
    }

    private func applyFont(to view: TabGTTerminalView) {
        let target = fontSettings.nsFont
        let current = view.font
        guard current.fontName != target.fontName || current.pointSize != target.pointSize else { return }
        view.font = target
    }
}
