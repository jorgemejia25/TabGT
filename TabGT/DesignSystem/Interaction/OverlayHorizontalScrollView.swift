import AppKit
import SwiftUI

/// Horizontal scroll container backed by `NSScrollView` with overlay scrollers.
///
/// Overlay scrollers float above the content (no layout shift) and macOS reveals
/// them automatically on hover or while scrolling.
struct OverlayHorizontalScrollView<Content: View>: NSViewRepresentable {
    var contentSize: CGSize
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = true

        let hostingView = NSHostingView(rootView: content())
        scrollView.documentView = hostingView

        context.coordinator.hostingView = hostingView
        context.coordinator.scrollView = scrollView
        context.coordinator.apply(contentSize: contentSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.hostingView?.rootView = content()
        context.coordinator.apply(contentSize: contentSize)
    }

    final class Coordinator {
        weak var hostingView: NSHostingView<Content>?
        weak var scrollView: NSScrollView?

        func apply(contentSize: CGSize) {
            guard let hostingView, let scrollView else { return }

            hostingView.frame = NSRect(origin: .zero, size: contentSize)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
