import Foundation

/// Opens a detached terminal window via SwiftUI `openWindow(id:value:)`.
struct DetachedWindowPayload: Codable, Hashable, Identifiable {
    var windowID: UUID
    var focusedGroupID: UUID

    var id: UUID { windowID }
}
