import Foundation

enum SecureFileStore {
    static let directoryPermissions: NSNumber = 0o700
    static let filePermissions: NSNumber = 0o600

    static func ensureDirectory(
        _ directoryURL: URL,
        fileManager: FileManager
    ) throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let parentURL = directoryURL.deletingLastPathComponent()
        if parentURL.lastPathComponent == "TabGT" {
            try restrictDirectory(parentURL, fileManager: fileManager)
        }

        try restrictDirectory(directoryURL, fileManager: fileManager)
    }

    private static func restrictDirectory(
        _ directoryURL: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.setAttributes(
            [.posixPermissions: directoryPermissions],
            ofItemAtPath: directoryURL.path
        )

        var mutableURL = directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableURL.setResourceValues(resourceValues)
    }

    static func write(_ data: Data, to fileURL: URL, fileManager: FileManager) throws {
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: filePermissions],
            ofItemAtPath: fileURL.path
        )
    }
}
