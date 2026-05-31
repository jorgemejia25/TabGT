import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct TerminalTabDragPayload: Codable, Hashable, Transferable {
    var sessionID: UUID
    var sourceGroupID: UUID?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    var encodedValue: NSString {
        if let sourceGroupID {
            return "\(sessionID.uuidString)|\(sourceGroupID.uuidString)" as NSString
        }
        return sessionID.uuidString as NSString
    }

    init(sessionID: UUID, sourceGroupID: UUID?) {
        self.sessionID = sessionID
        self.sourceGroupID = sourceGroupID
    }

    init?(string: String) {
        let parts = string.split(separator: "|", maxSplits: 1).map(String.init)
        guard !parts.isEmpty else { return nil }
        guard let sessionID = UUID(uuidString: parts[0]) else { return nil }

        self.sessionID = sessionID
        self.sourceGroupID = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
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
