import Combine
import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum InspectorSectionID: String, CaseIterable, Codable, Identifiable, Hashable {
    case connection
    case session
    case claudeCode
    case git
    case workspace
    case automations
    case snippets
    case clipTray
    case security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection:
            return "Connection"
        case .session:
            return "Session"
        case .claudeCode:
            return "Claude Code"
        case .git:
            return "Git"
        case .workspace:
            return "Workspace"
        case .automations:
            return "Automations"
        case .snippets:
            return "Snippets"
        case .clipTray:
            return "Clip Tray"
        case .security:
            return "Security"
        }
    }

    var systemImage: String {
        switch self {
        case .connection:
            return "network"
        case .session:
            return "terminal"
        case .claudeCode:
            return "sparkles"
        case .git:
            return "arrow.triangle.branch"
        case .workspace:
            return "folder"
        case .automations:
            return "bolt"
        case .snippets:
            return "text.quote"
        case .clipTray:
            return "doc.on.clipboard"
        case .security:
            return "lock.shield"
        }
    }

    var expandedStorageKey: String {
        "tabgt.inspector.expanded.\(rawValue)"
    }

    var defaultExpanded: Bool {
        switch self {
        case .connection, .claudeCode, .git, .workspace, .automations, .snippets, .clipTray:
            return true
        case .session, .security:
            return false
        }
    }

    /// Sections that only render when an SSH host is attached to the active session.
    var requiresSSHHost: Bool {
        self == .claudeCode
    }
}

struct InspectorSectionDragPayload: Codable, Hashable, Transferable {
    var sectionID: InspectorSectionID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@MainActor
final class InspectorLayoutStore: ObservableObject {
    static let shared = InspectorLayoutStore()

    private static let orderKey = "tabgt.inspector.sectionOrder"
    private static let hiddenKey = "tabgt.inspector.hiddenSections"

    @Published private(set) var orderedSections: [InspectorSectionID]
    @Published private(set) var hiddenSections: Set<InspectorSectionID>

    init(
        orderedSections: [InspectorSectionID]? = nil,
        hiddenSections: Set<InspectorSectionID>? = nil
    ) {
        self.orderedSections = Self.loadOrder(stored: orderedSections)
        self.hiddenSections = Self.loadHidden(stored: hiddenSections)
    }

    func isVisible(_ section: InspectorSectionID) -> Bool {
        !hiddenSections.contains(section)
    }

    func setVisible(_ section: InspectorSectionID, visible: Bool) {
        if visible {
            hiddenSections.remove(section)
        } else {
            hiddenSections.insert(section)
        }
        persistHidden()
    }

    func moveSection(_ draggedID: InspectorSectionID, before targetID: InspectorSectionID) {
        guard draggedID != targetID else { return }
        guard let targetIndex = orderedSections.firstIndex(of: targetID) else { return }
        moveSection(draggedID, toInsertionIndex: targetIndex)
    }

    func moveSection(_ draggedID: InspectorSectionID, after targetID: InspectorSectionID) {
        guard draggedID != targetID else { return }
        guard let targetIndex = orderedSections.firstIndex(of: targetID) else { return }
        moveSection(draggedID, toInsertionIndex: targetIndex + 1)
    }

    func moveSection(
        _ draggedID: InspectorSectionID,
        toDisplayedInsertionIndex insertionIndex: Int,
        in displayedSections: [InspectorSectionID]
    ) {
        guard !displayedSections.isEmpty else { return }

        if insertionIndex <= 0 {
            moveSection(draggedID, before: displayedSections[0])
            return
        }

        if insertionIndex >= displayedSections.count {
            moveSection(draggedID, after: displayedSections[displayedSections.count - 1])
            return
        }

        moveSection(draggedID, before: displayedSections[insertionIndex])
    }

    func moveSection(_ draggedID: InspectorSectionID, toInsertionIndex insertionIndex: Int) {
        guard let fromIndex = orderedSections.firstIndex(of: draggedID) else { return }

        var targetIndex = max(0, min(insertionIndex, orderedSections.count))
        if targetIndex == fromIndex || targetIndex == fromIndex + 1 {
            return
        }

        orderedSections.remove(at: fromIndex)
        if fromIndex < targetIndex {
            targetIndex -= 1
        }
        orderedSections.insert(draggedID, at: targetIndex)
        persistOrder()
    }

    /// Appends the section to the end of the list.
    func moveSectionToEnd(_ draggedID: InspectorSectionID) {
        moveSection(draggedID, toInsertionIndex: orderedSections.count)
    }

    func resetToDefaults() {
        orderedSections = Self.defaultOrder
        hiddenSections = []
        persistOrder()
        persistHidden()
    }

    func visibleSections(hasSSHHost: Bool) -> [InspectorSectionID] {
        orderedSections.filter { section in
            isVisible(section) && isAvailable(section, hasSSHHost: hasSSHHost)
        }
    }

    func allHiddenSections() -> [InspectorSectionID] {
        orderedSections.filter { !isVisible($0) }
    }

    func showAllHiddenSections() {
        guard !hiddenSections.isEmpty else { return }
        hiddenSections.removeAll()
        persistHidden()
    }

    func isAvailable(_ section: InspectorSectionID, hasSSHHost: Bool) -> Bool {
        !section.requiresSSHHost || hasSSHHost
    }

    private static var defaultOrder: [InspectorSectionID] {
        InspectorSectionID.allCases
    }

    private static func loadOrder(stored: [InspectorSectionID]?) -> [InspectorSectionID] {
        let decoded = stored ?? decodeOrder(from: UserDefaults.standard.string(forKey: orderKey))
        return mergeWithDefaults(decoded)
    }

    private static func loadHidden(stored: Set<InspectorSectionID>?) -> Set<InspectorSectionID> {
        stored ?? decodeHidden(from: UserDefaults.standard.string(forKey: hiddenKey))
    }

    private static func decodeOrder(from raw: String?) -> [InspectorSectionID] {
        guard let raw,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([InspectorSectionID].self, from: data) else {
            return defaultOrder
        }
        return decoded
    }

    private static func decodeHidden(from raw: String?) -> Set<InspectorSectionID> {
        guard let raw,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([InspectorSectionID].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    private static func mergeWithDefaults(_ stored: [InspectorSectionID]) -> [InspectorSectionID] {
        var merged = stored.filter { InspectorSectionID.allCases.contains($0) }
        for section in defaultOrder where !merged.contains(section) {
            merged.append(section)
        }
        return merged
    }

    private func persistOrder() {
        guard let data = try? JSONEncoder().encode(orderedSections),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: Self.orderKey)
    }

    private func persistHidden() {
        let hiddenList = orderedSections.filter { hiddenSections.contains($0) }
        guard let data = try? JSONEncoder().encode(hiddenList),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: Self.hiddenKey)
    }
}
