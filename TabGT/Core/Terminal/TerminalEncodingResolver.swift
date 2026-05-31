import Foundation

/// Derives a short encoding label for status UI from process locale environment variables.
enum TerminalEncodingResolver {
    static func fromProcessEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let candidates = [
            environment["LC_ALL"],
            environment["LC_CTYPE"],
            environment["LANG"],
        ]

        for raw in candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            if let label = label(fromLocale: raw) {
                return label
            }
        }

        return "UTF-8"
    }

    private static func label(fromLocale locale: String) -> String? {
        let normalized = locale.lowercased()
        if normalized.contains("utf-8") || normalized.contains("utf8") {
            return "UTF-8"
        }

        let charset = locale.split(separator: ".").last.map(String.init) ?? locale
        guard !charset.isEmpty else { return nil }
        return charset.uppercased()
    }
}
