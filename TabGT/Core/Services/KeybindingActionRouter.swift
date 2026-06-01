import AppKit
import Foundation

@MainActor
final class KeybindingActionRouter {
    static let shared = KeybindingActionRouter()

    private(set) var context = KeybindingActionContext()
    private var contextsByWindow: [ObjectIdentifier: KeybindingActionContext] = [:]

    private init() {}

    func updateContext(_ context: KeybindingActionContext, for window: NSWindow? = nil) {
        if let window {
            contextsByWindow[ObjectIdentifier(window)] = context
            if NSApp.keyWindow == window {
                self.context = context
            }
        } else {
            self.context = context
        }
    }

    func removeContext(for window: NSWindow) {
        contextsByWindow.removeValue(forKey: ObjectIdentifier(window))
    }

    func perform(_ command: KeybindingCommand) {
        resolvedContext().perform(command)
    }

    private func resolvedContext() -> KeybindingActionContext {
        if let keyWindow = NSApp.keyWindow {
            let id = ObjectIdentifier(keyWindow)
            if let context = contextsByWindow[id] {
                return context
            }
        }
        return context
    }
}
