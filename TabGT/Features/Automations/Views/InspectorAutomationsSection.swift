import SwiftUI

struct InspectorAutomationsSection: View {
    @ObservedObject var viewModel: AutomationsViewModel
    @ObservedObject var snippets: SnippetsViewModel

    var body: some View {
        InspectorAccordionSection(
            title: "Automations",
            storageKey: "tabgt.inspector.expanded.automations",
            defaultExpanded: true
        ) {
            ForEach(viewModel.rules) { rule in
                automationRuleRow(rule)
            }

            Button {
                viewModel.presentCreateEditor()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("New Automation")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppTheme.selectionBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .padding(.top, 2)
        }
        .sheet(isPresented: $viewModel.isEditorPresented, onDismiss: {
            viewModel.dismissEditor()
        }) {
            AutomationEditorSheet(
                viewModel: viewModel,
                draft: $viewModel.editorDraft
            )
        }
    }

    private func automationRuleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: 8) {
            Image(systemName: rule.kind.systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(rule.triggerPattern)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.toggleRule(rule)
            } label: {
                automationStatusPill(enabled: rule.isEnabled)
            }
            .buttonStyle(.plainClickable)
            .help(rule.isEnabled ? "Click to disable" : "Click to enable")

            Button {
                viewModel.presentEditEditor(for: rule)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .help("Edit automation")
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") {
                viewModel.presentEditEditor(for: rule)
            }

            Button(rule.isEnabled ? "Disable" : "Enable") {
                viewModel.toggleRule(rule)
            }

            Button("Save as Snippet") {
                snippets.createFromAutomation(rule)
            }

            Divider()

            Button("Delete", role: .destructive) {
                viewModel.deleteRule(rule)
            }
        }
    }

    private func automationStatusPill(enabled: Bool) -> some View {
        Text(enabled ? "On" : "Off")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(enabled ? AppTheme.success : AppTheme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                AppTheme.elevatedPanel.opacity(enabled ? 0.85 : 0.55),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
    }
}
