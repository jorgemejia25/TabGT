import Testing
@testable import TabGT

@MainActor
struct SessionsViewModelProfileTests {
    private func makeViewModel() -> SessionsViewModel {
        SessionsViewModel(coordinator: WorkspaceCoordinator())
    }

    @Test func openLocalSessionAlwaysCreatesNewTab() {
        let viewModel = makeViewModel()
        let profile = LocalProfileSeeds.profiles().first!

        viewModel.openLocalSession(profile: profile)
        viewModel.openLocalSession(profile: profile)

        let localSessions = viewModel.sessions.filter { $0.kind.profileID == profile.id }
        #expect(localSessions.count == 2)
    }

    @Test func openSSHSessionAlwaysCreatesNewTab() {
        let viewModel = makeViewModel()
        let host = PreviewData.hosts[0]

        viewModel.openSSHSession(for: host)
        viewModel.openSSHSession(for: host)

        let hostSessions = viewModel.sessions.filter { $0.kind.hostID == host.id }
        #expect(hostSessions.count == 2)
    }

    @Test func openLocalSessionStoresWorkingDirectory() {
        let viewModel = makeViewModel()
        let profile = LocalProfileSeeds.profiles().first!
        let folder = StartupFolder(name: "Home", path: "~")

        viewModel.openLocalSession(profile: profile, workingDirectory: folder)

        guard let session = viewModel.sessions.last else {
            Issue.record("Expected a session to be created")
            return
        }

        if case .localShell(let profileID, let workingDirectory) = session.kind {
            #expect(profileID == profile.id)
            #expect(workingDirectory != nil)
        } else {
            Issue.record("Expected local shell session kind")
        }
    }

    @Test func openSSHSessionStoresRemotePath() {
        let viewModel = makeViewModel()
        let host = PreviewData.hosts[0]
        let folder = StartupFolder(name: "Workspace", path: "~/workspace")

        viewModel.openSSHSession(for: host, workingDirectory: folder)

        guard let session = viewModel.sessions.last else {
            Issue.record("Expected a session to be created")
            return
        }

        if case .ssh(let hostID, let workingDirectory) = session.kind {
            #expect(hostID == host.id)
            #expect(workingDirectory == "~/workspace")
        } else {
            Issue.record("Expected ssh session kind")
        }
    }
}
