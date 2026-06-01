import Foundation
import Testing
@testable import TabGT

struct SnippetLaunchResolverTests {
    private let hostID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
    private let homeFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000802")!
    private let workspaceFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000803")!

    private var host: SSHHost {
        SSHHost(
            id: hostID,
            name: "api-east-01",
            address: "10.0.0.5",
            username: "deploy",
            startupFolders: [
                StartupFolder(id: homeFolderID, name: "Home", path: "~"),
                StartupFolder(id: workspaceFolderID, name: "Workspace", path: "~/workspace")
            ],
            defaultStartupFolderID: homeFolderID
        )
    }

    @Test func resolvesProfileContextFromSSHSession() {
        let session = TerminalSession(
            title: "api-east-01",
            kind: .ssh(hostID: hostID, workingDirectory: "~/workspace"),
            state: .connected
        )

        let context = SnippetLaunchResolver.profileContext(
            for: session,
            hosts: [host],
            profiles: []
        )

        #expect(context?.folders.count == 2)
        #expect(context?.defaultFolderID == homeFolderID)
    }

    @Test func resolvesConfiguredStartupFolder() {
        let context = SnippetProfileContext(
            folders: host.startupFolders,
            defaultFolderID: host.defaultStartupFolderID
        )

        let folder = SnippetLaunchResolver.resolvedFolder(
            startupFolderID: workspaceFolderID,
            in: context
        )

        #expect(folder?.name == "Workspace")
        #expect(folder?.path == "~/workspace")
    }

    @Test func fallsBackToProfileDefaultFolder() {
        let context = SnippetProfileContext(
            folders: host.startupFolders,
            defaultFolderID: host.defaultStartupFolderID
        )

        let folder = SnippetLaunchResolver.resolvedFolder(
            startupFolderID: nil,
            in: context
        )

        #expect(folder?.name == "Home")
    }

    @Test func launchSummaryIncludesFolderName() {
        let snippet = CommandSnippet(
            title: "Deploy",
            trigger: "deploy",
            command: "make deploy",
            launchMode: .newTabCopy,
            startupFolderID: workspaceFolderID
        )
        let context = SnippetProfileContext(
            folders: host.startupFolders,
            defaultFolderID: host.defaultStartupFolderID
        )

        let summary = SnippetLaunchResolver.launchSummary(for: snippet, context: context)
        #expect(summary == "New tab · Workspace")
    }
}

@MainActor
struct SnippetsViewModelLaunchTests {
    @Test func runUsesCurrentTabByDefault() {
        let bridge = SessionInputBridge()
        let viewModel = SnippetsViewModel(snippets: [], inputBridge: bridge)
        let sessionID = UUID()

        let snippet = CommandSnippet(
            title: "Deploy",
            trigger: "deploy",
            command: "make deploy"
        )

        viewModel.run(snippet, from: sessionID)

        let pending = bridge.pendingRequest(for: sessionID)
        #expect(pending?.text == "make deploy")
        #expect(pending?.submit == true)
    }

    @Test func runInNewTabCopyOpensDuplicateSessionAndQueuesCommand() {
        let bridge = SessionInputBridge()
        let sessions = SessionsViewModel(coordinator: WorkspaceCoordinator())
        let connections = ConnectionsViewModel(groups: [], hosts: [
            SSHHost(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
                name: "staging",
                address: "staging.internal",
                username: "dev",
                credentialRef: CredentialRef(kind: .agent, label: "Agent")
            )
        ])
        let profiles = TerminalProfilesViewModel(profiles: LocalProfileSeeds.profiles())

        let viewModel = SnippetsViewModel(
            snippets: [],
            inputBridge: bridge
        )
        viewModel.wireLaunchDependencies(
            sessions: sessions,
            connections: connections,
            terminalProfiles: profiles
        )

        let hostID = connections.hosts[0].id
        sessions.openSSHSession(for: connections.hosts[0])

        guard let sourceSessionID = sessions.selectedSession?.id else {
            Issue.record("Expected active SSH session")
            return
        }

        let snippet = CommandSnippet(
            title: "Deploy",
            trigger: "deploy",
            command: "make deploy",
            launchMode: .newTabCopy
        )

        viewModel.runInNewTab(snippet, from: sourceSessionID)

        #expect(sessions.sessions.count == 2)
        guard let newSession = sessions.selectedSession else {
            Issue.record("Expected duplicate session to be selected")
            return
        }
        #expect(newSession.id != sourceSessionID)
        if case .ssh(let copiedHostID, _) = newSession.kind {
            #expect(copiedHostID == hostID)
        } else {
            Issue.record("Expected SSH duplicate session")
        }

        let pending = bridge.pendingRequest(for: newSession.id)
        #expect(pending?.text == "make deploy")
        #expect(pending?.submit == true)
    }
}
