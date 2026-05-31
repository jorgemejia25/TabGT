import SwiftUI

struct TerminalInputLineView: View {
    var sessionID: UUID
    var prompt: String
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var sessions: SessionsViewModel
    @EnvironmentObject private var terminalFontSettings: TerminalFontSettings

    @State private var input = ""
    @FocusState private var isFocused: Bool
    @State private var selectedSuggestionIndex = 0

    private var suggestions: [CommandSnippet] {
        snippets.matchingSnippets(for: input)
    }

    private var showSuggestions: Bool {
        isFocused
            && !input.isEmpty
            && !suggestions.isEmpty
            && !suggestions.contains(where: { $0.command == input })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showSuggestions {
                suggestionList
            }

            HStack(spacing: 0) {
                Text(prompt)
                    .foregroundStyle(TerminalTheme.command)

                TextField("", text: $input)
                    .textFieldStyle(.plain)
                    .font(terminalFontSettings.swiftUIFont)
                    .foregroundStyle(TerminalTheme.foreground)
                    .focused($isFocused)
                    .onSubmit(submit)
                    .onKeyPress(.tab) {
                        applySelectedSuggestion(submitAfter: false)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(-1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        moveSelection(1)
                        return .handled
                    }

                Rectangle()
                    .fill(TerminalTheme.foreground)
                    .frame(width: 7, height: 15)
                    .opacity(isFocused ? 1 : 0.35)
            }
            .font(terminalFontSettings.swiftUIFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .onChange(of: input) { _, _ in
            selectedSuggestionIndex = 0
        }
        .onChange(of: snippets.pendingInputFill) { _, fill in
            guard let fill, fill.sessionID == sessionID else { return }
            input = fill.text
            snippets.clearPendingInputFill()
            isFocused = true
            if fill.submit {
                submit()
            }
        }
        .onAppear {
            applyPendingFillIfNeeded()
        }
        .contextMenu {
            if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Save as Snippet") {
                    snippets.createFromCommand(input, sessionID: sessionID)
                }
            }
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.prefix(5).enumerated()), id: \.element.id) { index, snippet in
                Button {
                    selectedSuggestionIndex = index
                    applySelectedSuggestion(submitAfter: false)
                } label: {
                    HStack(spacing: 8) {
                        Text(snippet.trigger)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.selectionBlue)
                            .frame(width: 42, alignment: .leading)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(snippet.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            Text(snippet.command)
                                .font(terminalFontSettings.swiftUIFont(size: CGFloat(terminalFontSettings.size - 1)))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(
                        index == selectedSuggestionIndex
                            ? AppTheme.selectionBlue.opacity(0.12)
                            : Color.clear
                    )
                }
                .buttonStyle(.plainClickable)
            }
        }
        .background(AppTheme.elevatedPanel.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.panelStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func applyPendingFillIfNeeded() {
        guard let fill = snippets.consumePendingInputFill(for: sessionID) else { return }
        input = fill.text
        isFocused = true
        if fill.submit {
            submit()
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        let maxIndex = min(suggestions.count, 5) - 1
        selectedSuggestionIndex = min(max(selectedSuggestionIndex + delta, 0), maxIndex)
    }

    private func applySelectedSuggestion(submitAfter: Bool) {
        guard !suggestions.isEmpty else { return }
        let index = min(selectedSuggestionIndex, min(suggestions.count, 5) - 1)
        input = suggestions[index].command
        if submitAfter {
            submit()
        }
    }

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sessions.submitCommand(trimmed, for: sessionID)
        input = ""
        selectedSuggestionIndex = 0
    }
}
