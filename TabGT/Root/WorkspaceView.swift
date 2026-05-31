import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    var body: some View {
        TerminalWorkspaceView(
            viewModel: sessions,
            connections: connections,
            terminalProfiles: terminalProfiles,
            snippets: snippets,
            inputBridge: inputBridge
        )
    }
}
