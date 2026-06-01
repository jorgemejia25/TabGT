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
            workingDirectory: session.kind.workingDirectory,
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
    var workingDirectory: String?
    var host: SSHHost
    var launchConfig: SSHLaunchConfig
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @ObservedObject var fontSettings: TerminalFontSettings
    @ObservedObject var automations: AutomationsViewModel

    func makeCoordinator() -> SSHSessionCoordinator {
        SSHSessionCoordinator(
            sessionID: sessionID,
            host: host,
            launchConfig: launchConfig,
            sessions: sessions
        )
    }

    func makeNSView(context: Context) -> TerminalSurfaceHostView {
        let surfaceHost = TerminalSurfaceHostView()
        let terminal = resolveTerminal(context: context, configureIfNeeded: true)
        surfaceHost.host(terminal)
        return surfaceHost
    }

    func updateNSView(_ nsView: TerminalSurfaceHostView, context: Context) {
        let terminal = resolveTerminal(context: context, configureIfNeeded: false)
        nsView.host(terminal)
        applyTheme(to: terminal)
        applyFont(to: terminal)

        if let retry = sessions.sshRetryRequest,
           retry.sessionID == sessionID,
           retry.id != context.coordinator.lastRetryRequestID {
            context.coordinator.lastRetryRequestID = retry.id
            context.coordinator.retryConnection()
        }

        deliverInputIfReady(to: terminal, context: context)
    }

    private func deliverInputIfReady(to terminal: TabGTTerminalView, context: Context) {
        SessionInputDelivery.deliverIfNeeded(
            to: terminal,
            sessionID: sessionID,
            sessions: sessions,
            inputBridge: inputBridge,
            isInputDeliveryReady: context.coordinator.isInputDeliveryReady,
            lastRequestID: &context.coordinator.lastRequestID
        )
    }

    static func dismantleNSView(_ nsView: TerminalSurfaceHostView, coordinator: SSHSessionCoordinator) {
        nsView.detachHostedTerminal()
    }

    private func resolveTerminal(
        context: Context,
        configureIfNeeded: Bool
    ) -> TabGTTerminalView {
        let terminal: TabGTTerminalView
        if let cached = TerminalViewPool.shared.view(for: sessionID) {
            terminal = cached
        } else {
            let view = TabGTTerminalView(frame: .zero)
            view.focusRingType = .none
            let extraEnvironment = SSHConfigBuilder.refreshedExtraEnvironment(for: host, from: launchConfig)
            view.launchProcess(
                executable: SSHConfigBuilder.sshPath,
                args: launchConfig.args,
                extraEnvironment: extraEnvironment
            )
            TerminalViewPool.shared.store(view, for: sessionID)
            terminal = view
        }

        terminal.pasteMode = TerminalPasteMode.forRemoteShell(
            host.remoteShell,
            workingDirectory: workingDirectory
        )
        terminal.processDelegate = context.coordinator
        context.coordinator.terminalView = terminal

        guard configureIfNeeded, !context.coordinator.isTerminalConfigured else {
            return terminal
        }

        context.coordinator.markTerminalConfigured()
        terminal.snippetProvider = { snippets.snippets }
        terminal.directoryChangeHandler = { path in
            Task { @MainActor in
                context.coordinator.reportDirectoryChange(path)
            }
        }
        terminal.outputCallback = makeOutputCallback()
        terminal.claudeOSCCallback = makeClaudeOSCCallback()
        terminal.gitOSCCallback = makeGitOSCCallback()
        terminal.connectionOutputCallback = { [weak coordinator = context.coordinator] text in
            guard let coordinator else { return }
            DispatchQueue.main.async {
                coordinator.processConnectionOutput(text)
            }
        }
        terminal.applyTabGTKeyboardSettings()
        context.coordinator.onInputDeliveryReady = { [weak coordinator = context.coordinator] in
            guard let coordinator,
                  let terminal = coordinator.terminalView else {
                return
            }
            SessionInputDelivery.deliverIfNeeded(
                to: terminal,
                sessionID: sessionID,
                sessions: sessions,
                inputBridge: inputBridge,
                isInputDeliveryReady: coordinator.isInputDeliveryReady,
                lastRequestID: &coordinator.lastRequestID
            )
        }
        context.coordinator.publishInitialGeometry(from: terminal)
        deliverInputIfReady(to: terminal, context: context)
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

    private func makeClaudeOSCCallback() -> (String, String) -> Void {
        let sessionsRef = sessions
        let sid = sessionID
        return { event, data in
            Task { @MainActor in
                sessionsRef.processClaudeOSCEvent(event, data: data, sessionID: sid)
            }
        }
    }

    private func makeGitOSCCallback() -> (String, String) -> Void {
        let sessionsRef = sessions
        let sid = sessionID
        return { event, data in
            Task { @MainActor in
                sessionsRef.processGitOSCEvent(event, data: data, sessionID: sid)
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
