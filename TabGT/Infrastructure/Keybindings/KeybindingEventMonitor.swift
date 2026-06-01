import AppKit
import SwiftUI

struct KeybindingEventMonitor: NSViewRepresentable {
    @ObservedObject var store: KeybindingStore
    var context: KeybindingActionContext
    var isEnabled: () -> Bool

    func makeNSView(context: Context) -> KeybindingMonitorView {
        let view = KeybindingMonitorView()
        view.configure(store: store, context: self.context, isEnabled: isEnabled)
        return view
    }

    func updateNSView(_ nsView: KeybindingMonitorView, context: Context) {
        nsView.configure(store: store, context: self.context, isEnabled: isEnabled)
    }
}

final class KeybindingMonitorView: NSView {
    private var monitor: Any?
    private weak var store: KeybindingStore?
    private var context = KeybindingActionContext()
    private var isEnabled: () -> Bool = { true }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func configure(
        store: KeybindingStore,
        context: KeybindingActionContext,
        isEnabled: @escaping () -> Bool
    ) {
        self.store = store
        self.context = context
        self.isEnabled = isEnabled
        installMonitorIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitorIfNeeded()
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil, window != nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let store = self.store else { return event }
            guard self.isEnabled() else { return event }
            guard self.shouldHandle(event) else { return event }

            if let command = store.command(for: event) {
                self.context.perform(command)
                return nil
            }

            if let tabIndex = Self.focusTabIndex(from: event) {
                self.context.focusTabAtIndex(tabIndex)
                return nil
            }

            return event
        }
    }

    private static func focusTabIndex(from event: NSEvent) -> Int? {
        guard event.type == .keyDown else { return nil }
        guard KeybindingModifier.from(eventFlags: event.modifierFlags) == [.command] else { return nil }
        guard let character = event.charactersIgnoringModifiers,
              character.count == 1,
              let digit = Int(character),
              (1 ... 9).contains(digit) else {
            return nil
        }
        return digit - 1
    }

    private func shouldHandle(_ event: NSEvent) -> Bool {
        guard window == NSApp.keyWindow else { return false }

        guard event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty == false else {
            return false
        }

        if NSApp.keyWindow?.attachedSheet != nil {
            return false
        }

        // Keep Option-only input (e.g. `@` via Option+Q) in the terminal.
        if TerminalKeyboardFocus.isTerminalFocused,
           !event.modifierFlags.contains(.command) {
            return false
        }

        if let firstResponder = NSApp.keyWindow?.firstResponder,
           firstResponder is NSTextView || firstResponder is NSTextField {
            return true
        }

        return true
    }
}
