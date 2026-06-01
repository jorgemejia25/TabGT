import SwiftUI

// MARK: - Key–value rows

struct InspectorRow: View {
    var label: String
    var value: String
    var monospacedValue: Bool = false
    var valueLineLimit: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: InspectorMetrics.labelWidth, alignment: .leading)

            Text(displayValue)
                .font(valueFont)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(valueLineLimit)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: InspectorMetrics.rowHeight)
    }

    private var displayValue: String {
        value.isEmpty ? "—" : value
    }

    private var valueFont: Font {
        monospacedValue
            ? .system(size: 11, weight: .regular, design: .monospaced)
            : .system(size: 11, weight: .regular)
    }
}

struct InspectorRowGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, InspectorMetrics.contentInset)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InspectorMetrics.contentFill, in: InspectorMetrics.contentShape)
        .overlay(
            InspectorMetrics.contentShape
                .stroke(AppTheme.panelStroke.opacity(0.45), lineWidth: 1)
        )
    }
}

struct InspectorGroupedList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InspectorMetrics.contentFill, in: InspectorMetrics.contentShape)
        .overlay(
            InspectorMetrics.contentShape
                .stroke(AppTheme.panelStroke.opacity(0.45), lineWidth: 1)
        )
        .clipShape(InspectorMetrics.contentShape)
    }
}

struct InspectorGroupedListDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.panelStroke.opacity(0.40))
            .frame(height: 1)
            .padding(.leading, InspectorMetrics.contentInset)
    }
}

struct InspectorGroupedListRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, InspectorMetrics.contentInset)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty states & actions

struct InspectorEmptyState: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InspectorMetrics.contentInset)
            .padding(.vertical, 6)
            .background(InspectorMetrics.contentFill, in: InspectorMetrics.contentShape)
            .overlay(
                InspectorMetrics.contentShape
                    .stroke(AppTheme.panelStroke.opacity(0.45), lineWidth: 1)
            )
    }
}

struct InspectorLinkButton: View {
    var title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(role == .destructive ? AppTheme.danger : AppTheme.selectionBlue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainClickable)
    }
}

struct InspectorStatusPill: View {
    var title: String
    var isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(isActive ? AppTheme.success : AppTheme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isActive ? AppTheme.success : AppTheme.elevatedPanel).opacity(isActive ? 0.12 : 0.50),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? AppTheme.success.opacity(0.30) : AppTheme.panelStroke.opacity(0.70),
                        lineWidth: 1
                    )
            )
    }
}

struct InspectorInlineAction: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.elevatedPanel.opacity(0.55), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.panelStroke.opacity(0.60), lineWidth: 1)
                )
        }
        .buttonStyle(.plainClickable)
    }
}

// MARK: - Layout metrics

enum InspectorMetrics {
    static let labelWidth: CGFloat = 84
    static let rowHeight: CGFloat = 20
    static let panelInset: CGFloat = 12
    static let sectionVerticalGap: CGFloat = 4
    static let contentInset: CGFloat = 10
    static let contentSpacing: CGFloat = 6
    static let contentTopInset: CGFloat = 4
    static let contentBottomInset: CGFloat = 6
    static let headerHeight: CGFloat = 26
    static let cornerRadius: CGFloat = 6

    static var contentShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static var contentFill: Color {
        AppTheme.elevatedPanel.opacity(0.30)
    }
}
