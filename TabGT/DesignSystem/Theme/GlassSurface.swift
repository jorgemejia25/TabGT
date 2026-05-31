import SwiftUI

extension View {
    /// Shared liquid-glass panel surface used by sidebars and workspace chrome.
    func appGlassSurface() -> some View {
        background(.thinMaterial)
    }

    /// Draws 1 pt borders on the given edges using `AppTheme.shellBorder`.
    func shellEdgeBorder(_ edges: Edge.Set) -> some View {
        overlay {
            ShellEdgeBorder(edges: edges)
        }
    }
}

private struct ShellEdgeBorder: View {
    var edges: Edge.Set

    var body: some View {
        GeometryReader { _ in
            let color = AppTheme.shellBorder

            if includes(.top) {
                Rectangle()
                    .fill(color)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if includes(.bottom) {
                Rectangle()
                    .fill(color)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            if includes(.leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if includes(.trailing) {
                Rectangle()
                    .fill(color)
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .allowsHitTesting(false)
    }

    private func includes(_ edge: Edge) -> Bool {
        if edges.contains(.all) { return true }

        switch edge {
        case .top:
            return edges.contains(.top) || edges.contains(.vertical)
        case .bottom:
            return edges.contains(.bottom) || edges.contains(.vertical)
        case .leading:
            return edges.contains(.leading) || edges.contains(.horizontal)
        case .trailing:
            return edges.contains(.trailing) || edges.contains(.horizontal)
        }
    }
}
