import AppKit
import SwiftTerm
import SwiftUI

// MARK: - Local terminal view (SwiftTerm-backed)

struct LocalTerminalView: View {
    var session: TerminalSession
    var launchConfig: LocalShellLaunchConfig
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @EnvironmentObject private var terminalFontSettings: TerminalFontSettings
    @EnvironmentObject private var automations: AutomationsViewModel

    var body: some View {
        LocalTerminalNSViewRepresentable(
            sessionID: session.id,
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

// MARK: - NSViewRepresentable

private struct LocalTerminalNSViewRepresentable: NSViewRepresentable {
    var sessionID: UUID
    var launchConfig: LocalShellLaunchConfig
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @ObservedObject var fontSettings: TerminalFontSettings
    @ObservedObject var automations: AutomationsViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: sessionID, sessions: sessions)
    }

    func makeNSView(context: Context) -> TerminalSurfaceHostView {
        let host = TerminalSurfaceHostView()
        let terminal = resolveTerminal(context: context, configureIfNeeded: true)
        host.host(terminal)
        return host
    }

    func updateNSView(_ nsView: TerminalSurfaceHostView, context: Context) {
        let terminal = resolveTerminal(context: context, configureIfNeeded: false)
        nsView.host(terminal)

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

    static func dismantleNSView(_ nsView: TerminalSurfaceHostView, coordinator: Coordinator) {
        nsView.detachHostedTerminal()
    }

    /// Reuse the running view when it exists — prevents the PTY process from
    /// restarting when SwiftUI rebuilds the hierarchy (e.g., on pane split).
    private func resolveTerminal(context: Context, configureIfNeeded: Bool) -> TabGTTerminalView {
        let terminal: TabGTTerminalView
        if let cached = TerminalViewPool.shared.view(for: sessionID) {
            terminal = cached
        } else {
            let view = TabGTTerminalView(frame: .zero)
            view.focusRingType = .none
            view.launchShell(config: launchConfig)
            TerminalViewPool.shared.store(view, for: sessionID)
            terminal = view
        }

        terminal.pasteMode = TerminalPasteMode.forShellPath(launchConfig.shellPath)
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
        terminal.gitOSCCallback = makeGitOSCCallback()
        terminal.applyTabGTKeyboardSettings()
        applyTheme(to: terminal)
        applyFont(to: terminal, context: context)
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
                let title = sessionsRef.session(for: sid)?.title ?? "Terminal"
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

    private func applyFont(to view: TabGTTerminalView, context: Context) {
        let target = fontSettings.nsFont
        let current = view.font
        guard current.fontName != target.fontName || current.pointSize != target.pointSize else {
            return
        }
        view.font = target
    }

    typealias Coordinator = TerminalMetricsCoordinator
}

// MARK: - Filtered terminal view

/// Subclass of LocalProcessTerminalView that suppresses the cosmetic
/// "zsh: can't set tty pgrp: operation not permitted" warning printed
/// by zsh on startup when the app is launched from Xcode.
///
/// Root cause: Xcode's process inherits a controlling terminal; even
/// though forkpty() + login_tty() create a new session with the slave
/// PTY as the controlling terminal, tcsetpgrp() can still return EPERM
/// in that host environment. The shell continues to work normally — the
/// message is purely cosmetic. We filter it here so users never see it.
final class TabGTTerminalView: LocalProcessTerminalView {
    private var earlyFilterActive = true
    private var keyboardMonitor: Any?

    var pasteMode: TerminalPasteMode = .automatic

    var snippetProvider: (() -> [CommandSnippet])? {
        didSet { installKeyboardMonitorIfNeeded() }
    }

    /// Called with each chunk of decoded terminal output (after startup filtering).
    /// Invoked on whichever thread SwiftTerm uses for PTY reads — callers must dispatch to main if needed.
    var outputCallback: ((String) -> Void)?

    /// SSH-only hook for connection handshake monitoring.
    var connectionOutputCallback: ((String) -> Void)?

    /// Called when a submitted command changes the working directory.
    var directoryChangeHandler: ((String) -> Void)?

    /// Called with (event, data) when an OSC 9001 TabGT-Claude sequence is received.
    var claudeOSCCallback: ((String, String) -> Void)?

    /// Paste override: wrap in bracketed paste sequences only when the remote has enabled
    /// bracketed paste mode. In plain PowerShell prompts, LF-only paste keeps the
    /// text editable; PSReadLine may render those lines in reverse, so `pasteMode`
    /// prepares the payload before it is sent.
    override func paste(_ sender: Any) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        let normalized = TerminalPasteMode.bracketedPasteText(from: text)
        let needsBrackets = terminal.bracketedPasteMode
            && (normalized.contains("\n") || normalized.count > terminal.cols)
        if needsBrackets {
            send(data: EscapeSequences.bracketedPasteStart[0...])
            send(txt: normalized)
            send(data: EscapeSequences.bracketedPasteEnd[0...])
        } else {
            switch pasteMode {
            case .automatic:
                super.paste(sender)
            case .powerShell:
                send(txt: pasteMode.plainPasteText(from: text))
            }
        }
    }

    /// Called with (event, data) when an OSC 9001 TabGT-Git sequence is received.
    var gitOSCCallback: ((String, String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureKeyboardInput()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureKeyboardInput()
    }

    /// SwiftTerm defaults `optionAsMetaKey` to true, which sends ESC + key for Option
    /// combinations. On Spanish layouts `@` is Option+Q, so Meta mode blocks it.
    func applyTabGTKeyboardSettings() {
        optionAsMetaKey = false
    }

    private func configureKeyboardInput() {
        applyTabGTKeyboardSettings()
    }

    deinit {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureKeyboardInput()
        hideEmbeddedScroller()
        installKeyboardMonitorIfNeeded()
    }

    override func layout() {
        super.layout()
        hideEmbeddedScroller()
    }

    private func hideEmbeddedScroller() {
        for subview in subviews {
            guard let scroller = subview as? NSScroller else { continue }
            scroller.isHidden = true
            scroller.alphaValue = 0
            for constraint in scroller.constraints where constraint.firstAttribute == .width {
                constraint.constant = 0
            }
        }
    }

    func launchShell(config: LocalShellLaunchConfig) {
        startManagedProcess(
            executable: config.shellPath,
            args: config.shellArgs,
            currentDirectory: config.currentDirectory
        )
    }

    func launchProcess(executable: String, args: [String], extraEnvironment: [String: String] = [:]) {
        startManagedProcess(executable: executable, args: args, currentDirectory: nil, extraEnvironment: extraEnvironment)
    }

    /// Stops the current child process and starts a new one with the same terminal surface.
    func relaunchProcess(executable: String, args: [String], extraEnvironment: [String: String] = [:]) {
        earlyFilterActive = true
        terminate()
        startManagedProcess(executable: executable, args: args, currentDirectory: nil, extraEnvironment: extraEnvironment)
    }

    private func startManagedProcess(
        executable: String,
        args: [String],
        currentDirectory: String?,
        extraEnvironment: [String: String] = [:]
    ) {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["TERM_PROGRAM"] = "TabGT"
        env["COLORTERM"] = "truecolor"
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        ShellIntegration.applyLocalShellEnvironment(&env, shellPath: executable)

        let execName = URL(fileURLWithPath: executable).lastPathComponent
        startProcess(
            executable: executable,
            args: args,
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: execName,
            currentDirectory: currentDirectory
        )
    }

    func insertText(_ text: String, submit: Bool = false) {
        if let path = submittedDirectoryChange(from: text, submit: submit) {
            directoryChangeHandler?(path)
        }
        send(txt: text)
        if submit {
            send(txt: "\r")
        }
    }

    private func submittedDirectoryChange(from text: String, submit: Bool) -> String? {
        guard submit else { return nil }
        return TerminalDirectoryParser.directory(fromCommand: text)
    }

    private func reportDirectoryChangeFromCurrentLine() {
        guard let line = currentInputLine(),
              let path = TerminalDirectoryParser.directory(fromCommand: line) else {
            return
        }
        directoryChangeHandler?(path)
    }

    private func currentInputLine() -> String? {
        guard let line = terminal.getLine(row: terminal.buffer.y) else { return nil }
        let value = line.translateToString(trimRight: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    @discardableResult
    func expandSnippetIfMatching() -> Bool {
        guard let snippets = snippetProvider?(), !snippets.isEmpty else { return false }
        guard let line = terminal.getLine(row: terminal.buffer.y) else { return false }

        let endCol = min(max(terminal.buffer.x, 0), terminal.cols)
        let linePrefix = line.translateToString(trimRight: false, startCol: 0, endCol: endCol)
        let token = SnippetExpansionEngine.currentToken(from: linePrefix)
        guard let snippet = SnippetExpansionEngine.matchingSnippet(for: token, in: snippets) else {
            return false
        }

        let delta = SnippetExpansionEngine.expansionDelta(from: token, to: snippet.command)
        let backspaces = String(repeating: "\u{7F}", count: delta.backspaces)
        send(txt: backspaces + delta.text)
        return true
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil, window != nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.firstResponder === self else { return event }

            if self.consumeOptionComposedCharacter(from: event) {
                return nil
            }

            if event.keyCode == 36 {
                self.reportDirectoryChangeFromCurrentLine()
            }

            guard event.keyCode == 48,
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.option) else {
                return event
            }

            return self.expandSnippetIfMatching() ? nil : event
        }
    }

    /// Inserts layout-specific Option characters such as `@` (Option+Q on Spanish).
    @discardableResult
    private func consumeOptionComposedCharacter(from event: NSEvent) -> Bool {
        guard !optionAsMetaKey else { return false }

        let flags = event.modifierFlags
        guard flags.contains(.option) else { return false }
        guard !flags.contains(.command), !flags.contains(.control) else { return false }

        guard let composed = event.characters, !composed.isEmpty,
              let raw = event.charactersIgnoringModifiers, !raw.isEmpty else {
            return false
        }

        guard composed != raw else { return false }

        send(txt: composed)
        return true
    }

    // Intercept process output before it reaches the terminal emulator.
    override func dataReceived(slice: ArraySlice<UInt8>) {
        // Once past early startup, stream everything directly.
        guard earlyFilterActive else {
            notifyOutput(slice: slice)
            super.dataReceived(slice: slice)
            return
        }

        let bytes = Array(slice)

        // Try to decode as UTF-8 to inspect the content.
        guard let str = String(bytes: bytes, encoding: .utf8) else {
            super.dataReceived(slice: slice)
            return
        }

        // Turn off the filter after we've seen the first newline — that's
        // enough for all startup lines (including the error) to have arrived.
        if str.contains("\n") { earlyFilterActive = false }

        guard str.contains("can't set tty pgrp") else {
            // No error in this chunk — pass the original bytes unchanged.
            notifyOutput(slice: slice)
            super.dataReceived(slice: slice)
            return
        }

        // Remove every line that carries the error message, then feed the
        // remainder. Using Array(...)[...] avoids any ArraySlice index issues.
        let filtered = str
            .components(separatedBy: "\n")
            .filter { !$0.contains("can't set tty pgrp") }
            .joined(separator: "\n")

        let filteredBytes = Array(filtered.utf8)
        notifyOutput(slice: filteredBytes[...])
        super.dataReceived(slice: filteredBytes[...])
    }

    private func notifyOutput(slice: ArraySlice<UInt8>) {
        guard let text = String(bytes: Array(slice), encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        connectionOutputCallback?(text)

        let (claudeEvents, afterClaude) = ClaudeOSCParser.extract(from: text)
        for (event, data) in claudeEvents {
            claudeOSCCallback?(event, data)
        }

        let (gitEvents, cleaned) = GitOSCParser.extract(from: afterClaude)
        for (event, data) in gitEvents {
            gitOSCCallback?(event, data)
        }

        guard let callback = outputCallback else { return }
        callback(cleaned)
    }
}

enum TerminalPasteMode: Equatable {
    case automatic
    case powerShell

    private static let powerShellExecutableNames: Set<String> = [
        "powershell",
        "powershell.exe",
        "pwsh",
        "pwsh.exe"
    ]

    static func forShellPath(_ path: String?) -> TerminalPasteMode {
        guard let path else { return .automatic }
        let name = executableName(from: path)
        return powerShellExecutableNames.contains(name) ? .powerShell : .automatic
    }

    static func forRemoteShell(_ shell: String?, workingDirectory: String?) -> TerminalPasteMode {
        if forShellPath(shell) == .powerShell {
            return .powerShell
        }

        if shell == nil,
           let workingDirectory,
           isWindowsPath(workingDirectory) {
            return .powerShell
        }

        return .automatic
    }

    func plainPasteText(from text: String) -> String {
        switch self {
        case .automatic:
            return text
        case .powerShell:
            return Self.reversedNormalizedLines(in: text)
        }
    }

    static func bracketedPasteText(from text: String) -> String {
        normalizedLineEndings(in: text, replacement: "\n")
    }

    private static func executableName(from path: String) -> String {
        let normalized = path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        return normalized
            .split(separator: "/")
            .last
            .map { String($0).lowercased() } ?? normalized.lowercased()
    }

    private static func normalizedLineEndings(in text: String, replacement: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: replacement)
    }

    private static func reversedNormalizedLines(in text: String) -> String {
        let normalized = normalizedLineEndings(in: text, replacement: "\n")
        guard normalized.contains("\n") else { return normalized }
        return normalized
            .components(separatedBy: "\n")
            .reversed()
            .joined(separator: "\n")
    }

    private static func isWindowsPath(_ path: String) -> Bool {
        let chars = Array(path)
        if chars.count >= 3,
           chars[0].isLetter,
           chars[1] == ":",
           chars[2] == "\\" || chars[2] == "/" {
            return true
        }
        return path.contains("\\")
    }
}

// MARK: - Claude Code OSC parser

enum ClaudeOSCParser {
    // Matches: ESC ] 9001 ; tabgt-claude ; {event} ; {data} BEL
    private static let pattern = try! NSRegularExpression(
        pattern: "\\x1b\\]9001;tabgt-claude;([^;\\x07]*);([^\\x07]*)\\x07"
    )

    /// Extracts Claude Code OSC events from text, returning (events, cleaned text).
    static func extract(from text: String) -> (events: [(String, String)], cleaned: String) {
        guard text.contains("\u{1b}]9001;tabgt-claude;") else {
            return ([], text)
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = pattern.matches(in: text, range: range)

        var events: [(String, String)] = []
        for match in matches {
            let event = match.range(at: 1).location != NSNotFound
                ? nsText.substring(with: match.range(at: 1)) : ""
            let data = match.range(at: 2).location != NSNotFound
                ? nsText.substring(with: match.range(at: 2)) : ""
            events.append((event, data))
        }

        let cleaned = pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return (events, cleaned)
    }
}

// MARK: - Git OSC parser

enum GitOSCParser {
    // Matches: ESC ] 9001 ; tabgt-git ; {event} ; {data} BEL
    private static let pattern = try! NSRegularExpression(
        pattern: "\\x1b\\]9001;tabgt-git;([^;\\x07]*);([^\\x07]*)\\x07"
    )

    static func extract(from text: String) -> (events: [(String, String)], cleaned: String) {
        guard text.contains("\u{1b}]9001;tabgt-git;") else {
            return ([], text)
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = pattern.matches(in: text, range: range)

        var events: [(String, String)] = []
        for match in matches {
            let event = match.range(at: 1).location != NSNotFound
                ? nsText.substring(with: match.range(at: 1)) : ""
            let data = match.range(at: 2).location != NSNotFound
                ? nsText.substring(with: match.range(at: 2)) : ""
            events.append((event, data))
        }

        let cleaned = pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return (events, cleaned)
    }
}
