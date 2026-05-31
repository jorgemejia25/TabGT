import SwiftUI

struct TerminalSurfaceView: View {
    var session: TerminalSession
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @EnvironmentObject private var terminalFontSettings: TerminalFontSettings

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                Text("Last login: Sat May 30 17:31:08 on ttys004")
                    .font(terminalFontSettings.swiftUIFont)
                    .foregroundStyle(TerminalTheme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(session.transcript) { line in
                    Text(line.text)
                        .font(terminalFontSettings.swiftUIFont)
                        .foregroundStyle(color(for: line.style))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TerminalInputLineView(
                    sessionID: session.id,
                    prompt: prompt,
                    snippets: snippets,
                    sessions: sessions
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var prompt: String {
        switch session.kind {
        case .ssh:
            return "\(session.title):~$"
        case .localShell:
            return "tabgt %"
        case .diagnostic:
            return "diag >"
        }
    }

    private func color(for style: TerminalLineStyle) -> Color {
        switch style {
        case .command:
            return TerminalTheme.command
        case .output:
            return TerminalTheme.foreground
        case .warning:
            return TerminalTheme.warning
        case .error:
            return TerminalTheme.error
        case .system:
            return TerminalTheme.system
        }
    }
}
