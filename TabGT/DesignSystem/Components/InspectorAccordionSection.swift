import SwiftUI

struct InspectorAccordionSection<Content: View>: View {
    var title: String
    var storageKey: String
    var defaultExpanded: Bool
    @ViewBuilder var content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(
        title: String,
        storageKey: String,
        defaultExpanded: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.storageKey = storageKey
        self.defaultExpanded = defaultExpanded
        self.content = content
        _isExpanded = AppStorage(wrappedValue: defaultExpanded, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .padding(.top, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke.opacity(0.75))
                .frame(height: 1)
        }
    }
}
