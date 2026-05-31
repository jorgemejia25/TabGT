import Foundation

@MainActor
final class AppEnvironment {
    let sessionCoordinator: SessionCoordinator

    init(sessionCoordinator: SessionCoordinator) {
        self.sessionCoordinator = sessionCoordinator
    }

    convenience init() {
        self.init(sessionCoordinator: SessionCoordinator())
    }

    static let preview = AppEnvironment(
        sessionCoordinator: SessionCoordinator(sessions: PreviewData.sessions)
    )
}
