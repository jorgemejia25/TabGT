import Testing
@testable import TabGT

@MainActor
struct TerminalPasteModeTests {
    @Test func powerShellPasteKeepsLFAndCompensatesPSReadLineOrder() {
        let input = "first\nsecond\rthird\r\nfourth"

        let pasted = TerminalPasteMode.powerShell.plainPasteText(from: input)

        #expect(pasted == "fourth\nthird\nsecond\nfirst")
    }

    @Test func powerShellSingleLinePasteIsUnchanged() {
        let input = "echo '{}'"

        let pasted = TerminalPasteMode.powerShell.plainPasteText(from: input)

        #expect(pasted == input)
    }

    @Test func automaticPastePreservesClipboardLineEndings() {
        let input = "first\nsecond\rthird\r\nfourth"

        let pasted = TerminalPasteMode.automatic.plainPasteText(from: input)

        #expect(pasted == input)
    }

    @Test func bracketedPasteUsesLFLineEndings() {
        let input = "first\r\nsecond\rthird"

        let pasted = TerminalPasteMode.bracketedPasteText(from: input)

        #expect(pasted == "first\nsecond\nthird")
    }

    @Test func detectsPowerShellExecutables() {
        #expect(TerminalPasteMode.forShellPath("pwsh") == .powerShell)
        #expect(TerminalPasteMode.forShellPath("/opt/homebrew/bin/pwsh") == .powerShell)
        #expect(TerminalPasteMode.forShellPath("C:\\Program Files\\PowerShell\\7\\pwsh.exe") == .powerShell)
        #expect(TerminalPasteMode.forShellPath("/bin/zsh") == .automatic)
    }

    @Test func defaultsWindowsSSHDirectoryToPowerShellPasteMode() {
        #expect(TerminalPasteMode.forRemoteShell(nil, workingDirectory: "C:\\Users\\mejia") == .powerShell)
        #expect(TerminalPasteMode.forRemoteShell("cmd.exe", workingDirectory: "C:\\Users\\mejia") == .automatic)
        #expect(TerminalPasteMode.forRemoteShell("/bin/bash", workingDirectory: nil) == .automatic)
    }
}
