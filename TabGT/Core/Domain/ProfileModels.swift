import Foundation

struct StartupFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
}

struct LocalTerminalProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var shellPath: String
    var shellArgs: [String] = ["-l"]
    var startupFolders: [StartupFolder] = []
    var defaultStartupFolderID: UUID?
    var sortOrder: Int = 0
}

struct LocalShellLaunchConfig: Hashable {
    var shellPath: String
    var shellArgs: [String]
    var currentDirectory: String?
}

enum ProfileResolver {
    static func resolvedDefaultFolder(
        folders: [StartupFolder],
        defaultID: UUID?
    ) -> StartupFolder? {
        if let defaultID,
           let folder = folders.first(where: { $0.id == defaultID }) {
            return folder
        }
        return folders.first
    }

    static func expandLocalPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    static func validatedLocalDirectory(
        _ path: String,
        fileManager: FileManager = .default
    ) -> String? {
        let expanded = expandLocalPath(path)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return expanded
    }

    static func resolveLocalWorkingDirectory(
        for folder: StartupFolder?,
        fileManager: FileManager = .default
    ) -> (path: String?, warning: String?) {
        guard let folder else {
            return (fileManager.homeDirectoryForCurrentUser.path, nil)
        }

        if let valid = validatedLocalDirectory(folder.path, fileManager: fileManager) {
            return (valid, nil)
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        return (
            home,
            "Startup folder \"\(folder.name)\" not found; opened in home directory."
        )
    }

    static func sessionTitle(
        baseName: String,
        folder: StartupFolder?,
        defaultFolder: StartupFolder?
    ) -> String {
        guard let folder else { return baseName }
        if folder.id == defaultFolder?.id { return baseName }
        return "\(baseName) · \(folder.name)"
    }

    static func launchConfig(
        for profile: LocalTerminalProfile,
        workingDirectory: String?,
        preferredShellFallback: String = "/bin/zsh"
    ) -> LocalShellLaunchConfig {
        LocalShellLaunchConfig(
            shellPath: profile.shellPath.isEmpty ? preferredShellFallback : profile.shellPath,
            shellArgs: profile.shellArgs,
            currentDirectory: workingDirectory
        )
    }
}

enum LocalProfileSeeds {
    static let homeFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
    static let developerFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
    static let zshProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000711")!
    static let bashProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000712")!
    static let gitProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000713")!

    static func profiles() -> [LocalTerminalProfile] {
        let homeFolder = StartupFolder(id: homeFolderID, name: "Home", path: "~")
        let developerFolder = StartupFolder(id: developerFolderID, name: "Developer", path: "~/Developer")

        return [
            LocalTerminalProfile(
                id: zshProfileID,
                name: "zsh",
                shellPath: "/bin/zsh",
                shellArgs: ["-l"],
                startupFolders: [homeFolder],
                defaultStartupFolderID: homeFolderID,
                sortOrder: 0
            ),
            LocalTerminalProfile(
                id: bashProfileID,
                name: "bash",
                shellPath: "/bin/bash",
                shellArgs: ["-l"],
                startupFolders: [homeFolder],
                defaultStartupFolderID: homeFolderID,
                sortOrder: 1
            ),
            LocalTerminalProfile(
                id: gitProfileID,
                name: "Git",
                shellPath: "/bin/zsh",
                shellArgs: ["-l"],
                startupFolders: [developerFolder],
                defaultStartupFolderID: developerFolderID,
                sortOrder: 2
            )
        ]
    }
}

enum SSHHostSeeds {
    static func emptyCatalog() -> (groups: [HostGroup], hosts: [SSHHost]) {
        ([], [])
    }
}
