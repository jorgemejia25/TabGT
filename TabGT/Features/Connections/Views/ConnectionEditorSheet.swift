import SwiftUI

struct ConnectionEditorSheet: View {
    var host: SSHHost?
    var hosts: [SSHHost]
    var onSave: (SSHHost) -> Void
    var onDelete: (UUID) -> Void
    var onImportSSHConfig: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var hostAddress: String
    @State private var user: String
    @State private var port: String
    @State private var authMethod: ConnectionAuthMethod
    @State private var privateKeyPath: String
    @State private var password: String
    @State private var startupFolders: [StartupFolder]
    @State private var defaultFolderID: UUID?
    @State private var remoteShell: String
    @State private var testOutput = "Connection test has not run."
    @State private var validationMessage: String?

    private var isEditing: Bool { host != nil }

    init(
        host: SSHHost?,
        hosts: [SSHHost],
        onSave: @escaping (SSHHost) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onImportSSHConfig: @escaping () -> Void
    ) {
        self.host = host
        self.hosts = hosts
        self.onSave = onSave
        self.onDelete = onDelete
        self.onImportSSHConfig = onImportSSHConfig

        let formState = Self.formState(from: host)
        _displayName = State(initialValue: formState.displayName)
        _hostAddress = State(initialValue: formState.hostAddress)
        _user = State(initialValue: formState.user)
        _port = State(initialValue: formState.port)
        _authMethod = State(initialValue: formState.authMethod)
        _privateKeyPath = State(initialValue: formState.privateKeyPath)
        _password = State(initialValue: formState.password)
        _startupFolders = State(initialValue: formState.startupFolders)
        _defaultFolderID = State(initialValue: formState.defaultFolderID)
        _remoteShell = State(initialValue: formState.remoteShell)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorSection("Connection") {
                        fieldRow("Display name") {
                            compactTextField(text: $displayName)
                        }
                        fieldRow("Host") {
                            compactTextField(text: $hostAddress)
                        }
                        fieldRow("User") {
                            compactTextField(text: $user)
                        }
                        fieldRow("Port") {
                            compactTextField(text: $port)
                                .frame(width: 94)
                        }
                    }

                    editorSection("Authentication") {
                        fieldRow("Auth method") {
                            Picker("", selection: $authMethod) {
                                ForEach(ConnectionAuthMethod.allCases) { method in
                                    Text(method.label).tag(method)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 220, alignment: .leading)
                        }

                        if authMethod == .privateKey {
                            fieldRow("Private key path") {
                                compactTextField(text: $privateKeyPath)
                                Button("Browse") {}
                                    .font(.system(size: 12, weight: .medium))
                                    .buttonStyle(.plainClickable)
                            }
                        }

                        if authMethod == .password {
                            fieldRow("Password") {
                                compactSecureField(text: $password)
                            }
                            Text("Stored securely in Keychain.")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        HStack {
                            Spacer()
                            Button(action: onImportSSHConfig) {
                                Label("Load from ~/.ssh/config", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.plainClickable)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.selectionBlue)
                        }
                        .frame(height: 28)
                    }

                    editorSection("Startup") {
                        fieldRow("Remote shell") {
                            compactTextField(text: $remoteShell)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("e.g. /bin/zsh")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Text("Leave blank to use the server's default shell.")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)

                        StartupFoldersEditor(
                            folders: $startupFolders,
                            defaultFolderID: $defaultFolderID,
                            pathPlaceholder: "~/workspace",
                            browseTitle: "Choose remote path reference"
                        )
                        Text("Paths are applied on the remote host after SSH connects.")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    editorSection("Console") {
                        Text(testOutput)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                            .padding(10)
                            .background(TerminalTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.panelStroke, lineWidth: 1)
                            )
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.vertical, 10)
            }

            Divider()
                .overlay(AppTheme.panelStroke)

            sheetFooter
        }
        .frame(width: 620, height: 560)
        .background(AppTheme.current.windowBackground)
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Edit SSH Profile" : "New SSH Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(hosts.count) profiles available")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private var sheetFooter: some View {
        HStack(spacing: 8) {
            if isEditing, let host {
                Button("Delete", role: .destructive) {
                    onDelete(host.id)
                    dismiss()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)
            }

            Button("Test Connection") {
                testOutput = """
                $ ssh -T \(user)@\(hostAddress) -p \(port)
                Resolving host...
                Auth method: \(authMethod.label)
                Ready to connect. Real transport integration pending.
                """
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plainClickable)

            Spacer()

            Button("Cancel") { dismiss() }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)

            Button("Save") { saveHost() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.selectionBlue)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private struct FormState {
        var displayName = ""
        var hostAddress = ""
        var user = ""
        var port = "22"
        var authMethod = ConnectionAuthMethod.privateKey
        var privateKeyPath = "~/.ssh/id_ed25519"
        var password = ""
        var startupFolders: [StartupFolder] = []
        var defaultFolderID: UUID?
        var remoteShell = ""
    }

    private static func formState(from host: SSHHost?) -> FormState {
        guard let host else { return FormState() }

        var state = FormState()
        state.displayName = host.name
        state.hostAddress = host.address
        state.user = host.username
        state.port = "\(host.port)"
        state.startupFolders = host.startupFolders
        state.defaultFolderID = host.defaultStartupFolderID ?? host.startupFolders.first?.id
        state.remoteShell = host.remoteShell ?? ""

        if let credentialRef = host.credentialRef {
            switch credentialRef.kind {
            case .password:
                state.authMethod = .password
                if let account = credentialRef.keychainAccount {
                    state.password = SSHCredentialStorage.readPassword(account: account) ?? ""
                }
            case .privateKey:
                state.authMethod = .privateKey
                state.privateKeyPath = credentialRef.label
            case .agent:
                state.authMethod = .sshConfigAlias
            }
        }

        return state
    }

    private func saveHost() {
        validationMessage = nil

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Display name is required."
            return
        }
        guard !trimmedAddress.isEmpty else {
            validationMessage = "Host is required."
            return
        }
        guard SSHInputValidator.isValidHostAddress(trimmedAddress) else {
            validationMessage = "Host may contain only letters, numbers, dots, dashes, underscores, and IPv6 colons."
            return
        }
        guard !trimmedUser.isEmpty else {
            validationMessage = "User is required."
            return
        }
        guard SSHInputValidator.isValidUsername(trimmedUser) else {
            validationMessage = "User may contain only letters, numbers, dots, dashes, and underscores."
            return
        }
        guard let parsedPort = Int(trimmedPort), (1 ... 65535).contains(parsedPort) else {
            validationMessage = "Port must be a number between 1 and 65535."
            return
        }
        let trimmedShell = remoteShell.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedShell.isEmpty, !SSHInputValidator.isValidRemoteShell(trimmedShell) {
            validationMessage = "Remote shell must be an absolute Unix path or cmd.exe, powershell, or pwsh."
            return
        }
        if authMethod == .password {
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPassword.isEmpty else {
                validationMessage = "Password is required."
                return
            }
        }

        var saved = host ?? SSHHost(
            name: trimmedName,
            address: trimmedAddress,
            port: parsedPort,
            username: trimmedUser
        )
        saved.name = trimmedName
        saved.address = trimmedAddress
        saved.port = parsedPort
        saved.username = trimmedUser
        saved.startupFolders = startupFolders
        saved.defaultStartupFolderID = defaultFolderID ?? startupFolders.first?.id
        saved.remoteShell = trimmedShell.isEmpty ? nil : trimmedShell
        guard let credentialRef = makeCredentialRef(for: saved) else { return }
        saved.credentialRef = credentialRef

        onSave(saved)
        dismiss()
    }

    @discardableResult
    private func makeCredentialRef(for host: SSHHost) -> CredentialRef? {
        switch authMethod {
        case .password:
            let credentialID = self.host?.credentialRef?.id ?? UUID()
            let keychainAccount = self.host?.credentialRef?.keychainAccount
                ?? SSHCredentialStorage.keychainAccount(forHostID: host.id, credentialID: credentialID)
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try SSHCredentialStorage.savePassword(trimmedPassword, account: keychainAccount)
            } catch {
                validationMessage = "Could not store password in Keychain."
                return nil
            }

            return CredentialRef(
                id: credentialID,
                kind: .password,
                label: "Password",
                keychainAccount: keychainAccount
            )
        case .privateKey:
            if let previousAccount = self.host?.credentialRef?.keychainAccount,
               self.host?.credentialRef?.kind == .password {
                SSHCredentialStorage.deletePassword(account: previousAccount)
            }
            let trimmedPath = privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return CredentialRef(kind: .privateKey, label: trimmedPath.isEmpty ? "~/.ssh/id_ed25519" : trimmedPath)
        case .sshConfigAlias:
            if let previousAccount = self.host?.credentialRef?.keychainAccount,
               self.host?.credentialRef?.kind == .password {
                SSHCredentialStorage.deletePassword(account: previousAccount)
            }
            return CredentialRef(kind: .agent, label: "SSH config alias")
        }
    }

    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)

            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke)
                .frame(height: 1)
        }
    }

    private func fieldRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 126, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    private func compactTextField(text: Binding<String>) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(AppTheme.editor)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
    }

    private func compactSecureField(text: Binding<String>) -> some View {
        SecureField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .frame(maxWidth: 220, minHeight: 24, maxHeight: 24)
            .background(AppTheme.editor)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
    }
}

enum ConnectionAuthMethod: String, CaseIterable, Identifiable {
    case password
    case privateKey
    case sshConfigAlias

    var id: String { rawValue }

    var label: String {
        switch self {
        case .password:
            return "Password"
        case .privateKey:
            return "Private key"
        case .sshConfigAlias:
            return "SSH config alias"
        }
    }
}
