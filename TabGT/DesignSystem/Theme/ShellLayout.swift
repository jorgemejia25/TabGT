import CoreGraphics

/// Shared shell layout metrics so adjacent chrome rows align pixel-perfect.
enum ShellLayout {
    /// Main window toolbar (matches navigator traffic-light strip).
    static let toolbarHeight: CGFloat = 44

    /// Horizontal space reserved under the traffic lights when the sidebar is hidden.
    static let trafficLightClearanceWidth: CGFloat = 76

    /// Editor tab bar, inspector title bar, and equivalent secondary headers.
    static let panelHeaderHeight: CGFloat = 35

    /// Minimum width for a terminal tab before the strip scrolls.
    static let tabMinWidth: CGFloat = 80

    /// Preferred maximum width for a terminal tab when space allows.
    static let tabMaxWidth: CGFloat = 160
}
