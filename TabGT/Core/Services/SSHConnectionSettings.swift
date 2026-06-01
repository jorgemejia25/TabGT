import Foundation

/// User defaults for SSH connection retry behavior (Settings → SSH).
enum SSHConnectionSettings {
    static let retriesEnabledKey = "tabgt.ssh.connectionRetriesEnabled"
    static let maxRetriesKey = "tabgt.ssh.maxConnectionRetries"

    static let defaultRetriesEnabled = true
    static let defaultMaxRetries = 3
    static let minMaxRetries = 1
    static let maxMaxRetries = 10

    static var retriesEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: retriesEnabledKey) == nil {
                return defaultRetriesEnabled
            }
            return UserDefaults.standard.bool(forKey: retriesEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: retriesEnabledKey)
        }
    }

    static var maxRetries: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: maxRetriesKey)
            if stored == 0 { return defaultMaxRetries }
            return min(max(stored, minMaxRetries), maxMaxRetries)
        }
        set {
            let clamped = min(max(newValue, minMaxRetries), maxMaxRetries)
            UserDefaults.standard.set(clamped, forKey: maxRetriesKey)
        }
    }

    /// OpenSSH `ConnectionAttempts` (TCP-level tries per `ssh` launch).
    static var openSSHConnectionAttempts: Int {
        retriesEnabled ? maxRetries : 1
    }
}
