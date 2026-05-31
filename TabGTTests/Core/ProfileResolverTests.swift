import Foundation
import Testing
@testable import TabGT

struct ProfileResolverTests {
    @Test func resolvedDefaultFolderUsesExplicitDefault() {
        let home = StartupFolder(id: UUID(), name: "Home", path: "~")
        let projects = StartupFolder(id: UUID(), name: "Projects", path: "~/Projects")

        let resolved = ProfileResolver.resolvedDefaultFolder(
            folders: [home, projects],
            defaultID: projects.id
        )

        #expect(resolved?.id == projects.id)
    }

    @Test func resolvedDefaultFolderFallsBackToFirstFolder() {
        let home = StartupFolder(id: UUID(), name: "Home", path: "~")

        let resolved = ProfileResolver.resolvedDefaultFolder(
            folders: [home],
            defaultID: nil
        )

        #expect(resolved?.id == home.id)
    }

    @Test func expandLocalPathExpandsTilde() {
        let expanded = ProfileResolver.expandLocalPath("~/Developer")
        #expect(expanded.contains("Developer"))
        #expect(!expanded.contains("~"))
    }

    @Test func sessionTitleIncludesFolderWhenNotDefault() {
        let home = StartupFolder(id: UUID(), name: "Home", path: "~")
        let projects = StartupFolder(id: UUID(), name: "Projects", path: "~/Projects")

        let title = ProfileResolver.sessionTitle(
            baseName: "Git",
            folder: projects,
            defaultFolder: home
        )

        #expect(title == "Git · Projects")
    }

    @Test func sessionTitleOmitsFolderWhenDefault() {
        let home = StartupFolder(id: UUID(), name: "Home", path: "~")

        let title = ProfileResolver.sessionTitle(
            baseName: "zsh",
            folder: home,
            defaultFolder: home
        )

        #expect(title == "zsh")
    }
}
