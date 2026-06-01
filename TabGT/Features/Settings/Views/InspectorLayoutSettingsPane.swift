import SwiftUI

struct InspectorLayoutSettingsPane: View {
    @ObservedObject var layoutStore: InspectorLayoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                "Drag rows to reorder sections in the inspector or here. Turn sections off to hide them from the panel."
            )
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)

            InspectorSectionReorderList(
                sections: layoutStore.orderedSections,
                layoutStore: layoutStore
            ) { section in
                inspectorSectionRow(section)
            }
            .background(AppTheme.editor)
            .overlay {
                Rectangle()
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            }

            HStack(spacing: 10) {
                Button("Restore Defaults") {
                    layoutStore.resetToDefaults()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)
                .foregroundStyle(AppTheme.textSecondary)

                Spacer()
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectorSectionRow(_ section: InspectorSectionID) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 16)

            Toggle(isOn: visibilityBinding(for: section)) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            Image(systemName: section.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                if section.requiresSSHHost {
                    Text("Only shown for SSH sessions")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: section.requiresSSHHost ? 40 : 32)
        .contentShape(Rectangle())
        .draggable(InspectorSectionDragPayload(sectionID: section))
    }

    private func visibilityBinding(for section: InspectorSectionID) -> Binding<Bool> {
        Binding(
            get: { layoutStore.isVisible(section) },
            set: { layoutStore.setVisible(section, visible: $0) }
        )
    }
}
