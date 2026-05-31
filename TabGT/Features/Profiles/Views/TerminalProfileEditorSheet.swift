import AppKit
import SwiftUI

struct TerminalProfileEditorSheet: View {
    var profile: LocalTerminalProfile?
    var onSave: (LocalTerminalProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = "zsh"
    @State private var shellPath = "/bin/zsh"
    @State private var shellArgs = "-l"
    @State private var startupFolders: [StartupFolder] = []
    @State private var defaultFolderID: UUID?
    @State private var validationMessage: String?

    private var isEditing: Bool { profile != nil }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorSection("Profile") {
                        fieldRow("Display name") {
                            compactTextField(text: $name)
                        }
                        fieldRow("Shell path") {
                            compactTextField(text: $shellPath)
                            Button("Browse") { browseShell() }
                                .font(.system(size: 12, weight: .medium))
                                .buttonStyle(.plainClickable)
                        }
                        fieldRow("Shell args") {
                            compactTextField(text: $shellArgs)
                                .frame(width: 220)
                        }
                    }

                    editorSection("Startup Folders") {
                        StartupFoldersEditor(
                            folders: $startupFolders,
                            defaultFolderID: $defaultFolderID,
                            pathPlaceholder: "~/Developer",
                            browseTitle: "Choose startup folder"
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
        .frame(width: 620, height: 520)
        .background(AppTheme.current.windowBackground)
        .onAppear(perform: loadProfile)
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Edit Local Profile" : "New Local Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Configure shell executable and startup folders")
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
            Spacer()

            Button("Cancel") { dismiss() }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)

            Button("Save") { saveProfile() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.selectionBlue)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private func loadProfile() {
        guard let profile else {
            let home = StartupFolder(name: "Home", path: "~")
            startupFolders = [home]
            defaultFolderID = home.id
            return
        }

        name = profile.name
        shellPath = profile.shellPath
        shellArgs = profile.shellArgs.joined(separator: " ")
        startupFolders = profile.startupFolders
        defaultFolderID = profile.defaultStartupFolderID ?? profile.startupFolders.first?.id
    }

    private func saveProfile() {
        validationMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedShell = shellPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Display name is required."
            return
        }
        guard !trimmedShell.isEmpty else {
            validationMessage = "Shell path is required."
            return
        }
        guard FileManager.default.isExecutableFile(atPath: trimmedShell) else {
            validationMessage = "Shell executable not found at the given path."
            return
        }

        let args = shellArgs
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        var saved = profile ?? LocalTerminalProfile(name: trimmedName, shellPath: trimmedShell)
        saved.name = trimmedName
        saved.shellPath = trimmedShell
        saved.shellArgs = args.isEmpty ? ["-l"] : args
        saved.startupFolders = startupFolders
        saved.defaultStartupFolderID = defaultFolderID ?? startupFolders.first?.id

        onSave(saved)
        dismiss()
    }

    private func browseShell() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose shell executable"
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            shellPath = url.path
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
}
