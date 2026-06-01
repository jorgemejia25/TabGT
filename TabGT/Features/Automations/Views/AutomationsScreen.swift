import SwiftUI

struct AutomationsScreen: View {
    @ObservedObject var automations: AutomationsViewModel
    @ObservedObject var snippets: SnippetsViewModel

    @State private var manualEntry = ""
    @State private var manualDescription = ""

    var body: some View {
        VStack(spacing: 0) {
            screenHeader

            HStack(spacing: 0) {
                rulesPane
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(AppTheme.panelStroke.opacity(0.6))
                    .frame(width: 1)

                clipTrayPane
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.editor)
        .sheet(isPresented: $automations.isEditorPresented, onDismiss: automations.dismissEditor) {
            AutomationEditorSheet(viewModel: automations, draft: $automations.editorDraft)
        }
        .sheet(isPresented: $automations.isClipEditorPresented, onDismiss: automations.dismissClipEditor) {
            ClipEditorSheet(viewModel: automations, draft: $automations.clipEditorDraft)
        }
    }

    // MARK: - Screen Header

    private var screenHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Automations")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(
                    "\(automations.rules.count) rule\(automations.rules.count == 1 ? "" : "s") · \(automations.capturedClips.count) clip\(automations.capturedClips.count == 1 ? "" : "s")"
                )
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(AppTheme.toolbar)
        .shellEdgeBorder(.bottom)
    }

    // MARK: - Rules Pane

    private var rulesPane: some View {
        VStack(spacing: 0) {
            paneHeader("Rules", count: automations.rules.count) {
                Button {
                    automations.presentCreateEditor()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("New Automation Rule")
            }

            if automations.rules.isEmpty {
                paneEmptyState(
                    "No automation rules",
                    "Automate command sequences triggered by terminal output patterns.",
                    "bolt.fill"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(automations.rules) { rule in
                            ruleRow(rule)
                            if rule.id != automations.rules.last?.id {
                                Rectangle()
                                    .fill(AppTheme.panelStroke.opacity(0.4))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rule.kind.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(rule.triggerPattern)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                automations.toggleRule(rule)
            } label: {
                statusPill(enabled: rule.isEnabled)
            }
            .buttonStyle(.plainClickable)
            .help(rule.isEnabled ? "Disable" : "Enable")

            Button {
                automations.presentEditEditor(for: rule)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") { automations.presentEditEditor(for: rule) }
            Button(rule.isEnabled ? "Disable" : "Enable") { automations.toggleRule(rule) }
            Button("Save as Snippet") { snippets.createFromAutomation(rule) }
            Divider()
            Button("Delete", role: .destructive) { automations.deleteRule(rule) }
        }
    }

    // MARK: - Clip Tray Pane

    private var clipTrayPane: some View {
        VStack(spacing: 0) {
            paneHeader("Clip Tray", count: automations.capturedClips.count) {
                EmptyView()
            }

            clipEntryForm
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .shellEdgeBorder(.bottom)

            if automations.capturedClips.isEmpty {
                paneEmptyState(
                    "No clips captured",
                    "Clips captured from your sessions will appear here.",
                    "doc.on.clipboard"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(automations.capturedClips) { clip in
                            clipRow(clip)
                            if clip.id != automations.capturedClips.last?.id {
                                Rectangle()
                                    .fill(AppTheme.panelStroke.opacity(0.4))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var clipEntryForm: some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                TextField("Add clip manually", text: $manualEntry)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .onSubmit(submitClip)

                TextField("Description (optional)", text: $manualDescription)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .onSubmit(submitClip)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                AppTheme.editor.opacity(0.55),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.panelStroke.opacity(0.45), lineWidth: 1)
            )

            Button(action: submitClip) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        manualEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.textTertiary
                            : AppTheme.selectionBlue
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .disabled(manualEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Add to clip tray")
        }
    }

    private func submitClip() {
        guard automations.addManualClip(manualEntry, description: manualDescription) else { return }
        manualEntry = ""
        manualDescription = ""
    }

    private func clipRow(_ clip: CapturedClip) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if let desc = clip.description {
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                HStack(spacing: 4) {
                    Text("from \(clip.sourceLabel)")
                    Text("·")
                    Text(automations.relativeCaptureTime(for: clip))
                }
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Button {
                    automations.presentEditClip(for: clip)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Edit")

                Button {
                    automations.copyToPasteboard(clip)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Copy")

                Button {
                    automations.removeClip(clip)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Remove")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") { automations.presentEditClip(for: clip) }
            Button("Copy") { automations.copyToPasteboard(clip) }
            Divider()
            Button("Delete", role: .destructive) { automations.removeClip(clip) }
        }
    }

    // MARK: - Shared Helpers

    private func paneHeader<Trailing: View>(
        _ title: String,
        count: Int,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.4)

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(AppTheme.elevatedPanel, in: Capsule())

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(AppTheme.navigator)
        .shellEdgeBorder(.bottom)
    }

    private func paneEmptyState(_ title: String, _ message: String, _ icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(AppTheme.textTertiary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func statusPill(enabled: Bool) -> some View {
        Text(enabled ? "On" : "Off")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(enabled ? AppTheme.success : AppTheme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                AppTheme.elevatedPanel.opacity(enabled ? 0.85 : 0.55),
                in: Capsule()
            )
            .overlay(Capsule().stroke(AppTheme.panelStroke, lineWidth: 1))
    }
}
