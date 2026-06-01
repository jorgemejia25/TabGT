import Foundation
import CoreTransferable
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct TerminalTabDragPayload: Codable, Hashable, Transferable {
    var sessionID: UUID
    var sourceGroupID: UUID?
    var sourceWindowID: UUID?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    var encodedValue: NSString {
        var parts = [sessionID.uuidString]
        if let sourceGroupID {
            parts.append(sourceGroupID.uuidString)
        }
        if let sourceWindowID {
            parts.append(sourceWindowID.uuidString)
        }
        return parts.joined(separator: "|") as NSString
    }

    init(sessionID: UUID, sourceGroupID: UUID?, sourceWindowID: UUID? = nil) {
        self.sessionID = sessionID
        self.sourceGroupID = sourceGroupID
        self.sourceWindowID = sourceWindowID
    }

    init?(string: String) {
        let parts = string.split(separator: "|").map(String.init)
        guard let first = parts.first else { return nil }
        guard let sessionID = UUID(uuidString: first) else { return nil }

        self.sessionID = sessionID
        self.sourceGroupID = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        self.sourceWindowID = parts.count > 2 ? UUID(uuidString: parts[2]) : nil
    }

    init?(item: NSSecureCoding?) {
        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            self.init(string: string)
            return
        }

        if let string = item as? String {
            self.init(string: string)
            return
        }

        if let string = item as? NSString {
            self.init(string: string as String)
            return
        }

        return nil
    }
}

enum TabDragDrop {
    /// Rejects no-op drops (same tab, same position).
    static func shouldAccept(
        _ payload: TerminalTabDragPayload,
        in groupID: UUID,
        before targetSessionID: UUID? = nil
    ) -> Bool {
        if payload.sourceGroupID == groupID,
           payload.sessionID == targetSessionID {
            return false
        }
        return true
    }
}

#if os(macOS)
final class TabDragPasteboardWriter: NSObject, NSPasteboardWriting {
    let payload: TerminalTabDragPayload

    init(payload: TerminalTabDragPayload) {
        self.payload = payload
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [
            NSPasteboard.PasteboardType(UTType.json.identifier),
            .string
        ]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type.rawValue == UTType.json.identifier,
           let data = try? JSONEncoder().encode(payload) {
            return data
        }

        if type == .string {
            return payload.encodedValue as String
        }

        return nil
    }
}
#endif
