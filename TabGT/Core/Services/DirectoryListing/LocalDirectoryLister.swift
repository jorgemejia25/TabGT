import Foundation

struct LocalDirectoryLister: DirectoryListingService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func listDirectory(at path: String) async throws -> [FileTreeEntry] {
        let expanded = ProfileResolver.expandLocalPath(path)
        guard let validated = ProfileResolver.validatedLocalDirectory(expanded, fileManager: fileManager) else {
            throw DirectoryListingError.invalidPath
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: validated, isDirectory: true),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw DirectoryListingError.commandFailed(error.localizedDescription)
        }

        let entries = urls.compactMap { url -> FileTreeEntry? in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory ?? false
            return FileTreeEntry(
                name: url.lastPathComponent,
                path: url.path,
                isDirectory: isDirectory
            )
        }

        return FileTreeSorting.sorted(entries)
    }
}
