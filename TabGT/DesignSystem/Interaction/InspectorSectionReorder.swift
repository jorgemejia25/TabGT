import SwiftUI

extension View {
    func inspectorSectionDraggable(_ section: InspectorSectionID) -> some View {
        draggable(InspectorSectionDragPayload(sectionID: section))
    }
}

struct InspectorSectionReorderList<Row: View>: View {
    let sections: [InspectorSectionID]
    @ObservedObject var layoutStore: InspectorLayoutStore
    @ViewBuilder var row: (InspectorSectionID) -> Row

    var body: some View {
        VStack(spacing: 0) {
            InspectorSectionInsertionSlot(
                insertionIndex: 0,
                sections: sections,
                layoutStore: layoutStore
            )

            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                row(section)

                InspectorSectionInsertionSlot(
                    insertionIndex: index + 1,
                    sections: sections,
                    layoutStore: layoutStore
                )
            }
        }
    }
}

private struct InspectorSectionInsertionSlot: View {
    let insertionIndex: Int
    let sections: [InspectorSectionID]
    @ObservedObject var layoutStore: InspectorLayoutStore

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Color.clear
                .frame(height: 4)

            if isTargeted {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(AppTheme.selectionBlue)
                    .frame(height: 2)
                    .padding(.horizontal, InspectorMetrics.panelInset + 4)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isTargeted)
        .dropDestination(for: InspectorSectionDragPayload.self) { items, _ in
            guard let payload = items.first else { return false }
            layoutStore.moveSection(
                payload.sectionID,
                toDisplayedInsertionIndex: insertionIndex,
                in: sections
            )
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
