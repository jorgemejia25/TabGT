import Combine
import Foundation

struct VisibleTreeRow: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var isDirectory: Bool
    var isCurrentDirectory: Bool
}

enum WorkspaceFolderPhase: Equatable {
    case idle
    case loading
    case ready
    case unavailable(String)
    case failed(String)
}

@MainActor
final class WorkspaceFolderTreeViewModel: ObservableObject {
    @Published private(set) var phase: WorkspaceFolderPhase = .idle
    @Published private(set) var browsePath: String?
    @Published private(set) var visibleRows: [VisibleTreeRow] = []

    private var lister: DirectoryListingService?
    private var boundSessionID: UUID?
    private var reloadTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    var displayPath: String {
        guard let browsePath else { return "-" }
        return WorkspacePathDisplay.compact(browsePath)
    }

    var currentFolderName: String {
        guard let browsePath else { return "-" }
        return WorkspacePathDisplay.currentFolderName(browsePath)
    }

    var canGoUp: Bool {
        guard let browsePath else { return false }
        return WorkspacePathNavigation.canGoUp(from: browsePath)
    }

    var parentPath: String? {
        guard let browsePath else { return nil }
        return WorkspacePathNavigation.parent(of: browsePath)
    }

    func bind(session: TerminalSession?, host: SSHHost?) {
        boundSessionID = session?.id
        debounceTask?.cancel()
        reloadTask?.cancel()

        guard let session else {
            resetState()
            phase = .unavailable("No active session")
            return
        }

        switch session.kind {
        case .diagnostic:
            resetState()
            phase = .unavailable("Not available for diagnostic sessions")
            return
        case .ssh where session.state != .connected:
            resetState()
            browsePath = session.effectiveDirectory.map(canonicalPath)
            phase = .unavailable("Connect to browse remote folders")
            return
        default:
            break
        }

        guard let directory = session.effectiveDirectory, !directory.isEmpty else {
            resetState()
            phase = .unavailable("Working directory unavailable")
            return
        }

        guard let lister = DirectoryListingServiceFactory.make(for: session, host: host) else {
            resetState()
            phase = .unavailable("Folder browsing unavailable for this session")
            return
        }

        self.lister = lister
        browsePath = canonicalPath(directory)

        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, boundSessionID == session.id else { return }
            await reloadListing(sessionID: session.id)
        }
    }

    private func reloadListing(sessionID: UUID) async {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            phase = .loading
            visibleRows = []

            guard let browsePath, let lister else {
                phase = .unavailable("Working directory unavailable")
                return
            }

            do {
                let entries = try await lister.listDirectory(at: browsePath)
                guard !Task.isCancelled, boundSessionID == sessionID else { return }

                visibleRows = entries.map { entry in
                    VisibleTreeRow(
                        name: entry.name,
                        path: canonicalPath(entry.path),
                        isDirectory: entry.isDirectory,
                        isCurrentDirectory: false
                    )
                }
                phase = .ready
            } catch let error as DirectoryListingError {
                phase = .failed(error.localizedDescription)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }

        await reloadTask?.value
    }

    private func canonicalPath(_ path: String) -> String {
        if SSHConfigBuilder.isWindowsPath(path) {
            return WindowsPath.normalize(path)
        }
        return ProfileResolver.expandLocalPath(path)
    }

    private func resetState() {
        browsePath = nil
        visibleRows = []
        lister = nil
    }
}
