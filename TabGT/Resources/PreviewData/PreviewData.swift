import Foundation

enum PreviewData {
    static let productionGroup = HostGroup(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        name: "Production",
        colorName: "red",
        sortOrder: 0
    )

    static let stagingGroup = HostGroup(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
        name: "Staging",
        colorName: "yellow",
        sortOrder: 1
    )

    static let labGroup = HostGroup(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
        name: "Lab",
        colorName: "green",
        sortOrder: 2
    )

    static let groups = [productionGroup, stagingGroup, labGroup]

    static let hosts: [SSHHost] = [
        SSHHost(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            name: "api-east-01",
            address: "10.18.4.21",
            username: "deploy",
            groupID: productionGroup.id,
            tags: ["api", "critical"],
            credentialRef: CredentialRef(kind: .privateKey, label: "Production deploy key"),
            lastConnectedAt: Date(timeIntervalSinceNow: -3600)
        ),
        SSHHost(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            name: "worker-west-02",
            address: "10.18.8.32",
            username: "ops",
            groupID: productionGroup.id,
            tags: ["queue", "batch"],
            credentialRef: CredentialRef(kind: .agent, label: "SSH Agent"),
            lastConnectedAt: Date(timeIntervalSinceNow: -8200)
        ),
        SSHHost(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            name: "staging-app",
            address: "staging.internal",
            username: "developer",
            groupID: stagingGroup.id,
            tags: ["release", "debug"],
            credentialRef: CredentialRef(kind: .password, label: "Staging password")
        ),
        SSHHost(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!,
            name: "raspi-lab",
            address: "192.168.1.44",
            username: "pi",
            groupID: labGroup.id,
            tags: ["arm", "iot"],
            credentialRef: CredentialRef(kind: .privateKey, label: "Lab key")
        )
    ]

    static var sessions: [TerminalSession] {
        [
            TerminalSession(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
                title: "api-east-01",
                kind: .ssh(hostID: hosts[0].id, workingDirectory: nil),
                state: .connected,
                columns: 128,
                rows: 34,
                transcript: transcript(for: hosts[0])
            ),
            TerminalSession(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
                title: "zsh",
                kind: .localShell(
                    profileID: LocalProfileSeeds.zshProfileID,
                    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
                ),
                state: .connected,
                columns: 120,
                rows: 32,
                transcript: localTranscript
            )
        ]
    }

    static func transcript(for host: SSHHost) -> [TerminalLine] {
        [
            TerminalLine(style: .system, text: "TabGT secure shell preview"),
            TerminalLine(style: .output, text: "Connected to \(host.displayAddress)"),
            TerminalLine(style: .command, text: "$ uptime"),
            TerminalLine(style: .output, text: "16:42  up 42 days,  3:18,  load averages: 0.22 0.31 0.27"),
            TerminalLine(style: .command, text: "$ systemctl status tabgt-agent"),
            TerminalLine(style: .output, text: "active (running) since Sat 2026-05-30 11:03:10 CST")
        ]
    }

    static let localTranscript: [TerminalLine] = [
        TerminalLine(style: .system, text: "Local terminal support is macOS-first"),
        TerminalLine(style: .command, text: "% pwd"),
        TerminalLine(style: .output, text: "~/Projects/TabGT"),
        TerminalLine(style: .command, text: "% git status --short"),
        TerminalLine(style: .output, text: "working tree has local architecture scaffolding")
    ]

    static let automationRules: [AutomationRule] = [
        AutomationRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            name: "Custom Command",
            kind: .commandCapture,
            triggerPattern: "/my-command",
            isEnabled: true,
            notes: "Captures arguments from a slash command.",
            source: .commandInput,
            captureMode: .argumentAfterTrigger
        ),
        AutomationRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            name: "URL Extractor",
            kind: .urlExtractor,
            triggerPattern: "https?://",
            isEnabled: true,
            notes: "Stores links printed in terminal output.",
            source: .terminalOutput,
            captureMode: .entireMatch,
            extractPattern: #"https?://[^\s]+"#,
            captureGroupIndex: 0
        ),
        AutomationRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            name: "Git Branch Watch",
            kind: .gitBranchWatch,
            triggerPattern: "git checkout|git switch",
            isEnabled: true,
            notes: "Saves branch names after checkout commands.",
            source: .commandInput,
            captureMode: .argumentAfterTrigger
        ),
        AutomationRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
            name: "Output Regex",
            kind: .outputRegex,
            triggerPattern: ".*",
            isEnabled: false,
            notes: "Extracts ticket-style IDs from terminal output.",
            source: .terminalOutput,
            captureMode: .regexGroup,
            extractPattern: #"([A-Z]+-\d+)"#,
            captureGroupIndex: 1
        ),
        AutomationRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000405")!,
            name: "Session Bookmark",
            kind: .sessionBookmark,
            triggerPattern: "/bookmark",
            isEnabled: false,
            notes: "Keeps quick notes from a custom bookmark command.",
            source: .commandInput,
            captureMode: .argumentAfterTrigger
        )
    ]

    static let commandSnippets: [CommandSnippet] = [
        CommandSnippet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
            title: "NextGen Code",
            trigger: "nx",
            command: "/nextgen-code ",
            tags: ["claude", "ticket"],
            notes: "Opens Claude Code with a NextGen ticket placeholder."
        ),
        CommandSnippet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000602")!,
            title: "Git Status",
            trigger: "gs",
            command: "git status --short",
            tags: ["git"]
        ),
        CommandSnippet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000603")!,
            title: "Deploy Staging",
            trigger: "deploy",
            command: "make deploy-staging",
            tags: ["deploy", "staging"]
        ),
        CommandSnippet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000604")!,
            title: "Tail Logs",
            trigger: "logs",
            command: "journalctl -fu tabgt-agent",
            tags: ["ops"]
        ),
        CommandSnippet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000605")!,
            title: "Bookmark Note",
            trigger: "bm",
            command: "/bookmark ",
            tags: ["note"]
        )
    ]

    static let capturedClips: [CapturedClip] = [
        CapturedClip(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            value: "PROJ-12345",
            sourceLabel: "Output Regex · Local",
            capturedAt: Date(timeIntervalSinceNow: -120),
            description: "Latest captured ticket"
        ),
        CapturedClip(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
            value: "PROJ-12004",
            sourceLabel: "Output Regex · Local",
            capturedAt: Date(timeIntervalSinceNow: -1_080),
            description: nil
        ),
        CapturedClip(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000503")!,
            value: "feature/auth-flow",
            sourceLabel: "git checkout",
            capturedAt: Date(timeIntervalSinceNow: -3_600),
            description: nil
        )
    ]
}
