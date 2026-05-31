import Foundation

struct LocalClipTrayRepository {
    private let fileManager: FileManager
    private let customBaseURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, customBaseURL: URL? = nil) {
        self.fileManager = fileManager
        self.customBaseURL = customBaseURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    var clipTrayDirectoryURL: URL {
        if let customBaseURL {
            return customBaseURL
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("clip-tray", isDirectory: true)
    }

    var clipTrayFileURL: URL {
        clipTrayDirectoryURL.appendingPathComponent("clips.json")
    }

    func loadAll() throws -> [CapturedClip] {
        try ensureClipTrayDirectoryExists()

        guard fileManager.fileExists(atPath: clipTrayFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: clipTrayFileURL)
        let document = try decoder.decode(ClipTrayDocument.self, from: data)
        return document.clips
    }

    func saveAll(_ clips: [CapturedClip]) throws {
        try ensureClipTrayDirectoryExists()
        let document = ClipTrayDocument(clips: clips)
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: clipTrayFileURL, fileManager: fileManager)
    }

    private func ensureClipTrayDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(clipTrayDirectoryURL, fileManager: fileManager)
    }
}
