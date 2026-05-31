import SwiftUI

struct NewProfileTypeSheet: View {
    var onSelectSSH: () -> Void
    var onSelectLocal: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            VStack(spacing: 10) {
                profileTypeButton(
                    title: "SSH Profile",
                    subtitle: "Connect to a remote host",
                    systemImage: "server.rack",
                    action: onSelectSSH
                )

                profileTypeButton(
                    title: "Local Profile",
                    subtitle: "Run a shell on this Mac",
                    systemImage: "terminal",
                    action: onSelectLocal
                )
            }
            .padding(18)

            Divider()
                .overlay(AppTheme.panelStroke)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plainClickable)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.toolbar)
        }
        .frame(width: 420)
        .background(AppTheme.current.windowBackground)
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("New Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Choose the type of profile to create")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private func profileTypeButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.selectionBlue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.editor)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plainClickable)
    }
}
