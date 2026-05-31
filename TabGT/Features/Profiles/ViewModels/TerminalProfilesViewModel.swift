import Combine
import Foundation

@MainActor
final class TerminalProfilesViewModel: ObservableObject {
    @Published private(set) var profiles: [LocalTerminalProfile]

    private let repository: LocalProfileRepository

    init(profiles: [LocalTerminalProfile], repository: LocalProfileRepository? = nil) {
        self.profiles = profiles.sorted { $0.sortOrder < $1.sortOrder }
        self.repository = repository ?? LocalProfileRepository()
    }

    var defaultProfile: LocalTerminalProfile? {
        profiles.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    func profile(for id: UUID) -> LocalTerminalProfile? {
        profiles.first { $0.id == id }
    }

    func save(_ profile: LocalTerminalProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            var next = profile
            if next.sortOrder == 0, !profiles.isEmpty {
                next.sortOrder = (profiles.map(\.sortOrder).max() ?? -1) + 1
            }
            profiles.append(next)
        }
        profiles.sort { $0.sortOrder < $1.sortOrder }
        persist()
    }

    func delete(_ profileID: UUID) {
        profiles.removeAll { $0.id == profileID }
        persist()
    }

    func launchConfig(for session: TerminalSession) -> LocalShellLaunchConfig? {
        guard case .localShell(let profileID, let workingDirectory) = session.kind,
              let profile = profile(for: profileID) else {
            return nil
        }

        return ProfileResolver.launchConfig(
            for: profile,
            workingDirectory: workingDirectory,
            preferredShellFallback: UserDefaults.standard.string(forKey: "tabgt.preferredLocalShell") ?? "/bin/zsh"
        )
    }

    private func persist() {
        do {
            try repository.saveAll(profiles)
        } catch {
            // Persistence failures are non-fatal for the UI slice.
        }
    }

    static func live() -> TerminalProfilesViewModel {
        let repository = LocalProfileRepository()
        let profiles = (try? repository.loadAll()) ?? LocalProfileSeeds.profiles()
        return TerminalProfilesViewModel(profiles: profiles, repository: repository)
    }

    static func preview() -> TerminalProfilesViewModel {
        TerminalProfilesViewModel(profiles: LocalProfileSeeds.profiles())
    }
}
