import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var onManageLocalProfiles: (() -> Void)?
    var isModal: Bool = true

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var terminalFontSettings: TerminalFontSettings
    @ObservedObject private var inspectorLayout = InspectorLayoutStore.shared
    @ObservedObject private var keybindings = KeybindingStore.shared
    @AppStorage("tabgt.preferredLocalShell") private var shell = "/bin/zsh"
    @State private var selectedSection = SettingsSection.general
    @State private var restoreWindows = true
    @State private var confirmClose = true
    @State private var useSSHAgent = true
    @State private var strictHostChecking = true
    @AppStorage(SSHConnectionSettings.retriesEnabledKey) private var sshRetriesEnabled = SSHConnectionSettings.defaultRetriesEnabled
    @AppStorage(SSHConnectionSettings.maxRetriesKey) private var sshMaxRetries = SSHConnectionSettings.defaultMaxRetries
    @State private var isThemeImporterPresented = false
    @State private var themeImportError: ThemeImportError?
    @State private var showThemeImportError = false

    var body: some View {
        settingsLayout
            .background(AppTheme.current.windowBackground)
            .onAppear {
                keybindings.reload()
            }
            .fileImporter(
                isPresented: $isThemeImporterPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleThemeImport(result)
            }
            .alert(
                "Theme Import Failed",
                isPresented: $showThemeImportError,
                presenting: themeImportError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
    }

    @ViewBuilder
    private var settingsLayout: some View {
        let content = HStack(spacing: 0) {
            settingsSidebar

            Divider()
                .overlay(AppTheme.panelStroke)

            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(AppTheme.panelStroke)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        selectedPane
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if isModal {
                    Divider()
                        .overlay(AppTheme.panelStroke)

                    footer
                }
            }
        }

        if isModal {
            content.frame(width: 760, height: 520)
        } else {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16)
                        Text(section.title)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .foregroundStyle(selectedSection == section ? AppTheme.onSelectionText : AppTheme.textSecondary)
                    .background(
                        selectedSection == section ? AppTheme.selectionBlue : Color.clear,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                }
                .buttonStyle(.plainClickable)
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .frame(width: 178)
        .background(AppTheme.navigator)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedSection.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(selectedSection.subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    @ViewBuilder private var selectedPane: some View {
        switch selectedSection {
        case .general:
            settingsSection("Launch") {
                Toggle("Restore open terminal groups", isOn: $restoreWindows)
                Toggle("Confirm before closing connected sessions", isOn: $confirmClose)
            }
        case .terminal:
            settingsSection("Terminal") {
                settingRow("Default shell") {
                    compactTextField(text: $shell)
                        .frame(width: 220)
                }
                HStack {
                    Button("Manage local profiles…") {
                        onManageLocalProfiles?()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plainClickable)
                    .foregroundStyle(AppTheme.selectionBlue)
                    Spacer()
                }
                .frame(height: 28)
                settingRow("Font family") {
                    fontFamilyField
                        .frame(width: 280)
                        .help("PostScript or family name. Use commas for fallbacks, e.g. Fira Code, Menlo, monospace")
                }
                fontFamilyPresetsRow
                settingRow("Font size") {
                    Slider(
                        value: $terminalFontSettings.size,
                        in: TerminalFontSettings.minSize...TerminalFontSettings.maxSize,
                        step: 1
                    )
                    .frame(width: 180)
                    Text("\(Int(terminalFontSettings.size)) pt")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 44, alignment: .trailing)
                }
                settingRow("Preview") {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("The quick brown fox jumps over 13 lazy dogs.")
                            .font(terminalFontSettings.swiftUIFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(terminalFontSettings.resolvedFontDescription)
                            .font(.system(size: 10))
                            .foregroundStyle(
                                terminalFontSettings.isFontResolved
                                    ? AppTheme.textTertiary
                                    : AppTheme.warning
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                settingRow("Scrollback") {
                    Picker("", selection: .constant("10000")) {
                        Text("10,000 lines").tag("10000")
                        Text("50,000 lines").tag("50000")
                        Text("Unlimited").tag("unlimited")
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
        case .ssh:
            settingsSection("OpenSSH") {
                Toggle("Use SSH agent", isOn: $useSSHAgent)
                Toggle("Strict host key checking", isOn: $strictHostChecking)
                settingRow("Transport") {
                    Text("OpenSSH")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            settingsSection("Connection Retries") {
                Toggle("Retry failed connections", isOn: $sshRetriesEnabled)
                if sshRetriesEnabled {
                    settingRow("Max attempts") {
                        Stepper(value: $sshMaxRetries, in: SSHConnectionSettings.minMaxRetries ... SSHConnectionSettings.maxMaxRetries) {
                            Text("\(sshMaxRetries)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                Text(
                    sshRetriesEnabled
                        ? "Uses OpenSSH ConnectionAttempts=\(sshMaxRetries) and relaunches the session up to \(sshMaxRetries) times after handshake failures."
                        : "Retries are off; each session makes a single connection attempt."
                )
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .keybindings:
            settingsSection("Shortcuts") {
                ForEach(keybindings.resolvedBindings) { binding in
                    keybindingRow(binding.command.title, binding.chord.displayString)
                }
            }
            settingsSection("Configuration") {
                Text(keybindings.filePath)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Reveal in Finder") {
                        keybindings.revealInFinder()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plainClickable)
                    .foregroundStyle(AppTheme.selectionBlue)

                    Button("Restore Defaults") {
                        keybindings.resetToDefaults()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plainClickable)
                    .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(height: 28)

                if let loadError = keybindings.loadError {
                    Text(loadError.localizedDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Edit keybindings.json, then reopen Settings to apply changes.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .appearance:
            settingsSection("Built-in") {
                builtInThemeGrid
            }
            settingsSection("Custom") {
                customThemeSection
            }
        case .security:
            settingsSection("Security") {
                Toggle("Store credentials in Keychain", isOn: .constant(true))
                Toggle("Trust known_hosts by default", isOn: .constant(false))
                settingRow("Known hosts") {
                    Button("Open known_hosts") {}
                        .font(.system(size: 12, weight: .medium))
                        .buttonStyle(.plainClickable)
                }
            }
        case .inspector:
            settingsSection("Layout") {
                InspectorLayoutSettingsPane(layoutStore: inspectorLayout)
            }
        }
    }

    private var fontFamilyField: some View {
        TextField("Fira Code, Menlo, monospace", text: $terminalFontSettings.fontFamily)
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

    private var fontFamilyPresetsRow: some View {
        HStack(spacing: 12) {
            Text("Suggestions")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 132, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TerminalFontPreset.allCases) { preset in
                        Button {
                            terminalFontSettings.fontFamily = preset.fontFamilyValue
                        } label: {
                            Text(preset.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(AppTheme.editor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plainClickable)
                    }
                }
            }
        }
        .frame(height: 28)
    }

    private var builtInThemeGrid: some View {
        themeGrid(themes: ThemeCatalog.all)
    }

    private var customThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isThemeImporterPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                    Text("Import Theme…")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.editor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plainClickable)
            .foregroundStyle(AppTheme.selectionBlue)

            if themeStore.customThemes.isEmpty {
                Text("No custom themes imported")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                themeGrid(themes: themeStore.customThemes, allowsDelete: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func themeGrid(themes: [TabGTTheme], allowsDelete: Bool = false) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 148), spacing: 10)],
            spacing: 10
        ) {
            ForEach(themes) { theme in
                themeCard(theme, allowsDelete: allowsDelete)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleThemeImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            themeImportError = .fileReadFailed
            showThemeImportError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            importTheme(from: url)
        }
    }

    private func importTheme(from url: URL) {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try themeStore.importTheme(from: url)
        } catch let error as ThemeImportError {
            themeImportError = error
            showThemeImportError = true
        } catch {
            themeImportError = .decodeFailed(error.localizedDescription)
            showThemeImportError = true
        }
    }

    private func themeCard(_ theme: TabGTTheme, allowsDelete: Bool = false) -> some View {
        let isSelected = themeStore.selectedThemeID == theme.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                theme.windowBackground.frame(maxWidth: .infinity)
                theme.navigator.frame(maxWidth: .infinity)
                theme.editor.frame(maxWidth: .infinity)
                theme.selectionBlue.frame(maxWidth: .infinity)
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack(spacing: 6) {
                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if allowsDelete {
                    Button {
                        deleteCustomTheme(theme)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plainClickable)
                    .help("Delete custom theme")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.editor)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isSelected ? AppTheme.selectionBlue : AppTheme.panelStroke,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            themeStore.selectedThemeID = theme.id
        }
        .pointerCursor()
        .contextMenu {
            Button("Select Theme") {
                themeStore.selectedThemeID = theme.id
            }
            if allowsDelete {
                Button("Delete Theme", role: .destructive) {
                    deleteCustomTheme(theme)
                }
            }
        }
    }

    private func deleteCustomTheme(_ theme: TabGTTheme) {
        do {
            try themeStore.deleteCustomTheme(id: theme.id)
        } catch {
            themeImportError = .decodeFailed(error.localizedDescription)
            showThemeImportError = true
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.selectionBlue)
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)

            content()
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke)
                .frame(height: 1)
        }
    }

    private func settingRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 132, alignment: .leading)
            content()
            Spacer()
        }
        .frame(height: 30)
    }

    private func keybindingRow(_ command: String, _ shortcut: String) -> some View {
        HStack(spacing: 12) {
            Text(command)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 132, alignment: .leading)
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(AppTheme.editor)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                )
            Spacer()
        }
        .frame(height: 28)
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
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case terminal
    case ssh
    case keybindings
    case appearance
    case inspector
    case security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .terminal:
            return "Terminal"
        case .ssh:
            return "SSH"
        case .keybindings:
            return "Keybindings"
        case .appearance:
            return "Appearance"
        case .inspector:
            return "Inspector"
        case .security:
            return "Security"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Launch and workspace behavior"
        case .terminal:
            return "Shell, typography and scrollback"
        case .ssh:
            return "Transport and host verification"
        case .keybindings:
            return "Keyboard shortcuts for terminal groups"
        case .appearance:
            return "Theme and interface density"
        case .inspector:
            return "Section order and visibility"
        case .security:
            return "Keys, agents and local trust"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .terminal:
            return "terminal"
        case .ssh:
            return "network"
        case .keybindings:
            return "keyboard"
        case .appearance:
            return "paintpalette"
        case .inspector:
            return "sidebar.right"
        case .security:
            return "lock.shield"
        }
    }
}
