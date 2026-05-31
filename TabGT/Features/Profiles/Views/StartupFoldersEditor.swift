import AppKit
import SwiftUI

struct StartupFoldersEditor: View {
    @Binding var folders: [StartupFolder]
    @Binding var defaultFolderID: UUID?
    var pathPlaceholder: String = "~/projects"
    var browseTitle: String = "Choose Folder"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if folders.isEmpty {
                Text("No startup folders configured.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                // Show a quick-pick picker when there are multiple folders so the
                // user has an obvious control to switch the default.
                if folders.count > 1 {
                    defaultPicker
                }

                ForEach($folders) { $folder in
                    FolderRow(
                        folder: $folder,
                        isDefault: defaultFolderID == folder.id,
                        onSetDefault: { defaultFolderID = folder.id },
                        onRemove: { removeFolder(folder.id) },
                        onBrowse: { browseDirectory(into: $folder.path) },
                        pathPlaceholder: pathPlaceholder
                    )
                }
            }

            Button {
                addFolder()
            } label: {
                Label("Add Folder", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plainClickable)
            .foregroundStyle(AppTheme.selectionBlue)
            .padding(.top, 2)
        }
    }

    // MARK: - Default picker

    private var defaultPicker: some View {
        HStack(spacing: 12) {
            Text("Default")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 54, alignment: .leading)

            Picker("", selection: defaultPickerBinding) {
                ForEach(folders) { folder in
                    Text(folder.name.isEmpty ? folder.path : folder.name)
                        .tag(folder.id as UUID?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 220, alignment: .leading)
        }
        .frame(height: 26)
        .padding(.bottom, 4)
    }

    private var defaultPickerBinding: Binding<UUID?> {
        Binding(
            get: { defaultFolderID ?? folders.first?.id },
            set: { defaultFolderID = $0 }
        )
    }

    // MARK: - Mutations

    private func addFolder() {
        let folder = StartupFolder(name: "Folder \(folders.count + 1)", path: pathPlaceholder)
        folders.append(folder)
        if defaultFolderID == nil {
            defaultFolderID = folder.id
        }
    }

    private func removeFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        if defaultFolderID == id {
            defaultFolderID = folders.first?.id
        }
    }

    private func browseDirectory(into path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = browseTitle
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path
        }
    }
}

// MARK: - Row

/// A self-contained view for one folder row. Using a dedicated View struct ensures
/// SwiftUI tracks the `isDefault` dependency correctly — a plain function returning
/// `some View` can miss binding updates inside ForEach.
private struct FolderRow: View {
    @Binding var folder: StartupFolder
    var isDefault: Bool
    var onSetDefault: () -> Void
    var onRemove: () -> Void
    var onBrowse: () -> Void
    var pathPlaceholder: String

    var body: some View {
        HStack(spacing: 8) {
            // Radio button — sets this folder as the default on tap.
            Button(action: onSetDefault) {
                ZStack {
                    // Transparent rectangle expands the hit target to 24×24.
                    Color.clear
                    Image(systemName: isDefault ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isDefault ? AppTheme.selectionBlue : AppTheme.textTertiary)
                }
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .help("Set as default startup folder")

            // Folder name
            TextField("Name", text: $folder.name)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .frame(width: 120, height: 24)
                .background(AppTheme.editor)
                .overlay(Rectangle().stroke(AppTheme.panelStroke, lineWidth: 1))

            // Folder path
            TextField(pathPlaceholder, text: $folder.path)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(AppTheme.editor)
                .overlay(Rectangle().stroke(AppTheme.panelStroke, lineWidth: 1))

            Button("Browse", action: onBrowse)
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plainClickable)
            .help("Remove folder")
        }
        .frame(height: 30)
    }
}
