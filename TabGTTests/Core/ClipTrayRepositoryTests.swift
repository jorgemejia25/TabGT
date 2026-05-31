import Foundation
import Testing
@testable import TabGT

@MainActor
struct ClipTrayRepositoryTests {
    @Test func loadAllReturnsEmptyWhenFileMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalClipTrayRepository(customBaseURL: directory)

        let clips = try repository.loadAll()
        #expect(clips.isEmpty)
    }

    @Test func saveAndLoadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalClipTrayRepository(customBaseURL: directory)

        let clips = [
            CapturedClip(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
                value: "NXT-18237",
                sourceLabel: "Manual",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                description: "Sprint ticket"
            ),
            CapturedClip(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
                value: "feature/auth-flow",
                sourceLabel: "git checkout",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_100),
                description: nil
            )
        ]

        try repository.saveAll(clips)
        let loaded = try repository.loadAll()

        #expect(loaded.count == 2)
        #expect(loaded.map(\.value).sorted() == ["NXT-18237", "feature/auth-flow"])
        #expect(loaded.first(where: { $0.value == "NXT-18237" })?.description == "Sprint ticket")
    }

    @Test func documentEncodingRoundTrip() throws {
        let clips = PreviewData.capturedClips
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        let document = ClipTrayDocument(clips: clips)
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(ClipTrayDocument.self, from: data)

        #expect(decoded.clips.count == clips.count)
        #expect(decoded.clips.map(\.value).sorted() == clips.map(\.value).sorted())
    }
}
