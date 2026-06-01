import Foundation

enum SSHPrivateKeyHelper {
    private static var keyDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tabgt-ssh-keys", isDirectory: true)
    }

    static func isValidPEM(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("BEGIN") && trimmed.contains("PRIVATE KEY")
    }

    static func isInlineKey(_ credential: CredentialRef) -> Bool {
        credential.kind == .privateKey && credential.keychainAccount != nil
    }

    /// Returns the filesystem path OpenSSH should use for `-i`.
    static func resolvedKeyPath(for credential: CredentialRef) -> String? {
        guard credential.kind == .privateKey else { return nil }

        if let account = credential.keychainAccount,
           let pem = SSHCredentialStorage.readPassword(account: account) {
            return writePEMToTempFile(pem, account: account)
        }

        let path = (credential.label as NSString).expandingTildeInPath
        return path
    }

    static func writePEMToTempFile(_ pem: String, account: String) -> String? {
        let dir = keyDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700 as NSNumber],
                ofItemAtPath: dir.path
            )
        } catch {
            return nil
        }

        let keyURL = dir.appendingPathComponent("\(account).key")
        do {
            try pem.write(to: keyURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600 as NSNumber],
                ofItemAtPath: keyURL.path
            )
            return keyURL.path
        } catch {
            return nil
        }
    }

    static func removeKeyFile(account: String) {
        let keyURL = keyDirectory.appendingPathComponent("\(account).key")
        try? FileManager.default.removeItem(at: keyURL)
    }

    static func cleanup() {
        try? FileManager.default.removeItem(at: keyDirectory)
    }
}
