import SwiftUI

struct InspectorAccordionSection<Content: View>: View {
    var title: String
    var storageKey: String
    var defaultExpanded: Bool
    var systemImage: String?
    var reorderSectionID: InspectorSectionID?
    @ViewBuilder var content: () -> Content

    @AppStorage private var isExpanded: Bool
    @State private var isHeaderHovered = false

    init(
        title: String,
        storageKey: String,
        defaultExpanded: Bool = true,
        systemImage: String? = nil,
        reorderSectionID: InspectorSectionID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.storageKey = storageKey
        self.defaultExpanded = defaultExpanded
        self.systemImage = systemImage ?? reorderSectionID?.systemImage
        self.reorderSectionID = reorderSectionID
        self.content = content
        _isExpanded = AppStorage(wrappedValue: defaultExpanded, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: InspectorMetrics.contentSpacing) {
                    content()
                }
                .padding(.top, InspectorMetrics.contentTopInset)
                .padding(.bottom, InspectorMetrics.contentBottomInset)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, InspectorMetrics.panelInset)
        .padding(.vertical, InspectorMetrics.sectionVerticalGap / 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke.opacity(0.45))
                .frame(height: 1)
        }
        .contextMenu {
            if let reorderSectionID {
                Button(isExpanded ? "Collapse" : "Expand") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }

                Divider()

                Button("Hide \"\(reorderSectionID.title)\"", role: .destructive) {
                    InspectorLayoutStore.shared.setVisible(reorderSectionID, visible: false)
                }
            }
        }
    }

    private var sectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isExpanded ? AppTheme.selectionBlue : AppTheme.textTertiary)
                        .frame(width: 12)
                }

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(height: InspectorMetrics.headerHeight)
            .padding(.horizontal, 6)
            .background(
                isHeaderHovered ? AppTheme.rowHoverFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainClickable)
        .onHover { isHeaderHovered = $0 }
        .modifier(InspectorSectionDragModifier(sectionID: reorderSectionID))
    }
}

private struct InspectorSectionDragModifier: ViewModifier {
    var sectionID: InspectorSectionID?

    func body(content: Content) -> some View {
        if let sectionID {
            content.draggable(InspectorSectionDragPayload(sectionID: sectionID))
        } else {
            content
        }
    }
}
