import SwiftUI

struct InspectorAutomationsSection: View {
    @ObservedObject var viewModel: AutomationsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    var reorderSectionID: InspectorSectionID? = nil

    var body: some View {
        InspectorAccordionSection(
            title: "Automations",
            storageKey: "tabgt.inspector.expanded.automations",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            if viewModel.rules.isEmpty {
                InspectorEmptyState(message: "No automations yet")
            } else {
                InspectorGroupedList {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
                        if index > 0 {
                            InspectorGroupedListDivider()
                        }
                        automationRuleRow(rule)
                    }
                }
            }

            InspectorLinkButton(title: "New Automation", systemImage: "plus") {
                viewModel.presentCreateEditor()
            }
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
        InspectorGroupedListRow {
            HStack(spacing: 8) {
                Image(systemName: rule.kind.systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
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
                    InspectorStatusPill(title: rule.isEnabled ? "On" : "Off", isActive: rule.isEnabled)
                }
                .buttonStyle(.plainClickable)
                .help(rule.isEnabled ? "Click to disable" : "Click to enable")

                Button {
                    viewModel.presentEditEditor(for: rule)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Edit automation")
            }
        }
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
}
