import Testing
@testable import TabGT

@MainActor
struct SessionsViewModelTerminalMetricsTests {
    @Test func updateTerminalGeometryMutatesMatchingSession() {
        let viewModel = SessionsViewModel()
        let profile = LocalProfileSeeds.profiles().first!
        viewModel.openLocalSession(profile: profile)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected a session")
            return
        }

        viewModel.updateTerminalGeometry(sessionID: sessionID, columns: 142, rows: 41)

        let session = viewModel.session(for: sessionID)
        #expect(session?.columns == 142)
        #expect(session?.rows == 41)
    }

    @Test func updateTerminalGeometrySkipsWhenUnchanged() {
        let viewModel = SessionsViewModel()
        let profile = LocalProfileSeeds.profiles().first!
        viewModel.openLocalSession(profile: profile)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected a session")
            return
        }

        viewModel.updateTerminalGeometry(sessionID: sessionID, columns: 100, rows: 30)
        let first = viewModel.session(for: sessionID)
        viewModel.updateTerminalGeometry(sessionID: sessionID, columns: 100, rows: 30)
        let second = viewModel.session(for: sessionID)

        #expect(first?.columns == second?.columns)
        #expect(first?.rows == second?.rows)
    }

    @Test func updateTerminalGeometryDoesNotAffectOtherSessions() {
        let viewModel = SessionsViewModel()
        let profile = LocalProfileSeeds.profiles().first!
        viewModel.openLocalSession(profile: profile)
        viewModel.openLocalSession(profile: profile)

        guard viewModel.sessions.count == 2 else {
            Issue.record("Expected two sessions")
            return
        }

        let firstID = viewModel.sessions[0].id
        let secondID = viewModel.sessions[1].id

        viewModel.updateTerminalGeometry(sessionID: firstID, columns: 90, rows: 25)

        #expect(viewModel.session(for: firstID)?.columns == 90)
        #expect(viewModel.session(for: firstID)?.rows == 25)
        #expect(viewModel.session(for: secondID)?.columns == 120)
        #expect(viewModel.session(for: secondID)?.rows == 32)
    }

    @Test func updateSessionEncodingMutatesMatchingSession() {
        let viewModel = SessionsViewModel()
        let profile = LocalProfileSeeds.profiles().first!
        viewModel.openLocalSession(profile: profile)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected a session")
            return
        }

        viewModel.updateSessionEncoding(sessionID: sessionID, encoding: "ISO-8859-1")

        #expect(viewModel.session(for: sessionID)?.encoding == "ISO-8859-1")
    }
}

struct TerminalEncodingResolverTests {
    @Test func resolvesUTF8FromLocale() {
        let encoding = TerminalEncodingResolver.fromProcessEnvironment([
            "LANG": "en_US.UTF-8",
        ])
        #expect(encoding == "UTF-8")
    }

    @Test func fallsBackToUTF8WhenLocaleMissing() {
        let encoding = TerminalEncodingResolver.fromProcessEnvironment([:])
        #expect(encoding == "UTF-8")
    }
}
