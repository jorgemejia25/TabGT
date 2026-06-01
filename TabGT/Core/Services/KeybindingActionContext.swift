import Foundation

@MainActor
struct KeybindingActionContext {
    var newTerminal: () -> Void = {}
    var closeActiveTab: () -> Void = {}
    var splitRight: () -> Void = {}
    var splitDown: () -> Void = {}
    var toggleNavigator: () -> Void = {}
    var toggleInspector: () -> Void = {}
    var closeActiveGroup: () -> Void = {}
    var openSettings: () -> Void = {}
    var moveToNewWindow: () -> Void = {}
    var focusTabAtIndex: (Int) -> Void = { _ in }

    func perform(_ command: KeybindingCommand) {
        switch command {
        case .newTerminal:
            newTerminal()
        case .closeActiveTab:
            closeActiveTab()
        case .splitRight:
            splitRight()
        case .splitDown:
            splitDown()
        case .toggleNavigator:
            toggleNavigator()
        case .toggleInspector:
            toggleInspector()
        case .closeActiveGroup:
            closeActiveGroup()
        case .openSettings:
            openSettings()
        case .moveToNewWindow:
            moveToNewWindow()
        }
    }
}
