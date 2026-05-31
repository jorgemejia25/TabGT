import Foundation

@MainActor
final class KeybindingActionRouter {
    static let shared = KeybindingActionRouter()

    private(set) var context = KeybindingActionContext()

    private init() {}

    func updateContext(_ context: KeybindingActionContext) {
        self.context = context
    }

    func perform(_ command: KeybindingCommand) {
        context.perform(command)
    }
}
