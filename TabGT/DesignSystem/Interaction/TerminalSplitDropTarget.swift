#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Transparent AppKit drop surface that reports split placement while dragging.
///
/// SwiftUI `onContinuousHover` does not fire during an active drag session on macOS,
/// so VS Code-style edge previews require `draggingUpdated` from `NSDraggingDestination`.
struct TerminalSplitDropTarget: NSViewRepresentable {
    var onTargetedChanged: (Bool) -> Void
    var onPlacementChanged: (TerminalSplitPlacement?) -> Void
    var onDrop: (TerminalTabDragPayload, TerminalSplitPlacement?) -> Bool

    func makeNSView(context: Context) -> SplitDropTargetNSView {
        let view = SplitDropTargetNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SplitDropTargetNSView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTargetedChanged: onTargetedChanged,
            onPlacementChanged: onPlacementChanged,
            onDrop: onDrop
        )
    }

    final class Coordinator {
        let onTargetedChanged: (Bool) -> Void
        let onPlacementChanged: (TerminalSplitPlacement?) -> Void
        let onDrop: (TerminalTabDragPayload, TerminalSplitPlacement?) -> Bool

        init(
            onTargetedChanged: @escaping (Bool) -> Void,
            onPlacementChanged: @escaping (TerminalSplitPlacement?) -> Void,
            onDrop: @escaping (TerminalTabDragPayload, TerminalSplitPlacement?) -> Bool
        ) {
            self.onTargetedChanged = onTargetedChanged
            self.onPlacementChanged = onPlacementChanged
            self.onDrop = onDrop
        }

        func placement(at location: NSPoint, in size: NSSize) -> TerminalSplitPlacement? {
            SplitDropPlacement.placementAt(
                CGPoint(x: location.x, y: location.y),
                in: CGSize(width: size.width, height: size.height)
            )
        }
    }
}

final class SplitDropTargetNSView: NSView {
    var coordinator: TerminalSplitDropTarget.Coordinator?

    private static let dragTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType(UTType.json.identifier),
        .string
    ]

    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerForDraggedTypes(Self.dragTypes)
    }

    /// Pass normal mouse input through to the terminal below. The drag
    /// pasteboard can retain the last tab payload after a drag finishes, so it
    /// cannot be used by itself to decide whether this transparent view should
    /// capture hit testing.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point), !isUserMouseInteraction else { return nil }
        return TabDragPasteboard.isActive ? self : nil
    }

    private var isUserMouseInteraction: Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type.isTerminalSurfaceMouseEvent
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard TabDragPasteboard.payload(from: sender.draggingPasteboard) != nil else {
            return []
        }
        coordinator?.onTargetedChanged(true)
        updatePlacement(from: sender)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard TabDragPasteboard.payload(from: sender.draggingPasteboard) != nil else {
            return []
        }
        updatePlacement(from: sender)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        coordinator?.onTargetedChanged(false)
        coordinator?.onPlacementChanged(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            coordinator?.onTargetedChanged(false)
            coordinator?.onPlacementChanged(nil)
        }

        guard let payload = TabDragPasteboard.payload(from: sender.draggingPasteboard),
              let coordinator
        else {
            return false
        }

        let location = convert(sender.draggingLocation, from: nil)
        let placement = coordinator.placement(at: location, in: bounds.size)
        return coordinator.onDrop(payload, placement)
    }

    private func updatePlacement(from sender: NSDraggingInfo) {
        guard let coordinator else { return }
        let location = convert(sender.draggingLocation, from: nil)
        coordinator.onPlacementChanged(
            coordinator.placement(at: location, in: bounds.size)
        )
    }
}

private enum TabDragPasteboard {
    static var isActive: Bool {
        payload(from: NSPasteboard(name: .drag)) != nil
    }

    static func payload(from pasteboard: NSPasteboard) -> TerminalTabDragPayload? {
        let jsonType = NSPasteboard.PasteboardType(UTType.json.identifier)

        if let data = pasteboard.data(forType: jsonType),
           let payload = try? JSONDecoder().decode(TerminalTabDragPayload.self, from: data) {
            return payload
        }

        for type in pasteboard.types ?? [] {
            guard let data = pasteboard.data(forType: type),
                  let payload = try? JSONDecoder().decode(TerminalTabDragPayload.self, from: data)
            else { continue }
            return payload
        }

        if let string = pasteboard.string(forType: .string) {
            return TerminalTabDragPayload(string: string)
        }

        return nil
    }
}

private extension NSEvent.EventType {
    var isTerminalSurfaceMouseEvent: Bool {
        switch self {
        case .leftMouseDown,
             .leftMouseUp,
             .leftMouseDragged,
             .rightMouseDown,
             .rightMouseUp,
             .rightMouseDragged,
             .otherMouseDown,
             .otherMouseUp,
             .otherMouseDragged,
             .mouseMoved,
             .scrollWheel:
            return true
        default:
            return false
        }
    }
}
#endif
