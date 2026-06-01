#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// AppKit drag source for terminal tabs. Detects when a drag leaves the window
/// bounds and triggers detach, while writing the shared tab drag pasteboard.
struct TerminalTabDragSource: NSViewRepresentable {
    var payload: TerminalTabDragPayload
    var onSelect: () -> Void
    var onDragOutsideWindow: () -> Void

    func makeNSView(context: Context) -> TabDragSourceNSView {
        let view = TabDragSourceNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TabDragSourceNSView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.payload = payload
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            payload: payload,
            onSelect: onSelect,
            onDragOutsideWindow: onDragOutsideWindow
        )
    }

    final class Coordinator {
        var payload: TerminalTabDragPayload
        let onSelect: () -> Void
        let onDragOutsideWindow: () -> Void

        init(
            payload: TerminalTabDragPayload,
            onSelect: @escaping () -> Void,
            onDragOutsideWindow: @escaping () -> Void
        ) {
            self.payload = payload
            self.onSelect = onSelect
            self.onDragOutsideWindow = onDragOutsideWindow
        }
    }
}

final class TabDragSourceNSView: NSView, NSDraggingSource {
    var coordinator: TerminalTabDragSource.Coordinator?

    private var mouseDownLocation: NSPoint?
    private var didBeginDragSession = false
    private var didTriggerDetach = false

    override var isOpaque: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didBeginDragSession = false
        didTriggerDetach = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didBeginDragSession,
              let start = mouseDownLocation,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4,
              let coordinator
        else {
            return
        }

        didBeginDragSession = true

        let writer = TabDragPasteboardWriter(payload: coordinator.payload)
        let item = NSDraggingItem(pasteboardWriter: writer)
        item.setDraggingFrame(bounds, contents: nil as NSImage?)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            didBeginDragSession = false
            didTriggerDetach = false
        }

        guard !didBeginDragSession else { return }
        coordinator?.onSelect()
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard !didTriggerDetach, let window else { return }
        if !window.frame.contains(screenPoint) {
            didTriggerDetach = true
            coordinator?.onDragOutsideWindow()
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownLocation = nil
        didBeginDragSession = false
        didTriggerDetach = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }
}
#endif
