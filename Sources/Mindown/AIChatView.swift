import SwiftUI

/// Right-edge sidebar housing the AI chat assistant. Falls back to an API
/// key entry form when no key is configured; otherwise renders a chat
/// transcript with input field and inline approval cards for proposed
/// downloads.
struct AIChatView: View {
    @EnvironmentObject var settings: AISettings
    @ObservedObject var vm: ChatViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "AI ASSIST") {
                HStack(spacing: 6) {
                    LCDText(
                        text: settings.isConfigured ? settings.model.uppercased() : "SETUP",
                        color: WinampPalette.lcdAmber, size: 10
                    )
                    if settings.isConfigured && !vm.messages.isEmpty {
                        Button("NEW") { vm.resetConversation() }
                            .buttonStyle(WinampButtonStyle(minWidth: 42, height: 16))
                    }
                }
            }

            if settings.isConfigured {
                chatBody
            } else {
                APIKeyForm()
                    .environmentObject(settings)
            }
        }
        .background(WinampPalette.panelChrome)
        .overlay(
            // Left bevel so the sidebar reads as a separate panel from the
            // main content area.
            Rectangle()
                .fill(WinampPalette.bevelDark)
                .frame(width: 1)
                .frame(maxHeight: .infinity, alignment: .leading),
            alignment: .leading
        )
    }

    @ViewBuilder
    private var chatBody: some View {
        VStack(spacing: 0) {
            transcript
            inputBar
        }
        .background(WinampPalette.lcdBackground)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if vm.messages.isEmpty {
                        LCDText(text: "ask me to download a song or a video",
                                color: WinampPalette.lcdGreenDim, size: 11)
                            .padding(.vertical, 12)
                    }
                    ForEach(vm.messages) { msg in
                        ChatBubble(message: msg, vm: vm)
                            .id(msg.id)
                    }
                    if vm.isThinking {
                        LCDText(text: "thinking…",
                                color: WinampPalette.lcdAmber, size: 10)
                            .padding(.leading, 6)
                            .id("thinking")
                    }
                }
                .padding(8)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            ZStack {
                WinampPalette.lcdBackground
                TextField(
                    "",
                    text: $vm.draft,
                    prompt: Text("ask for a song or video…")
                        .foregroundColor(WinampPalette.lcdGreenDim)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(WinampPalette.lcdGreen)
                .padding(.horizontal, 6)
                .focused($inputFocused)
                .onSubmit { vm.sendDraft() }
            }
            .frame(height: 24)
            .overlay(BevelOverlay(inset: true))

            Button("SEND") { vm.sendDraft() }
                .buttonStyle(WinampButtonStyle(minWidth: 52, height: 24))
                .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isThinking)
        }
        .padding(8)
        .background(WinampPalette.panelChrome)
        .overlay(
            Rectangle().fill(WinampPalette.bevelDark).frame(height: 1),
            alignment: .top
        )
        .onAppear { inputFocused = true }
        .onChange(of: vm.refocusToken) { _, _ in
            // Bumped after each turn finishes / proposal resolves so focus
            // returns to the input without the user having to click first.
            inputFocused = true
        }
    }
}

// MARK: - API key form

private struct APIKeyForm: View {
    @EnvironmentObject var settings: AISettings
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LCDText(text: "configure your openai-compatible api",
                    color: WinampPalette.lcdGreenDim, size: 10)

            field("API KEY", text: $apiKey, placeholder: "sk-…", secure: true)
            field("BASE URL", text: $baseURL, placeholder: "https://api.openai.com/v1")
            field("MODEL", text: $model, placeholder: "gpt-4o-mini")

            Button("SAVE") {
                settings.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                settings.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                settings.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .buttonStyle(WinampButtonStyle(
                tint: WinampPalette.panelLight,
                labelColor: WinampPalette.lcdGreen,
                minWidth: 80, height: 22
            ))
            .disabled(apiKey.isEmpty || baseURL.isEmpty || model.isEmpty)

            LCDText(text: "works with openai, openrouter, groq, ollama (openai mode), etc.",
                    color: WinampPalette.lcdGreenDim, size: 9)
                .padding(.top, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WinampPalette.lcdBackground)
        .onAppear {
            apiKey = settings.apiKey
            baseURL = settings.baseURL
            model = settings.model
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LCDText(text: label, color: WinampPalette.lcdGreenDim, size: 10)
            ZStack {
                WinampPalette.lcdBackground
                Group {
                    if secure {
                        SecureField("", text: text,
                                    prompt: Text(placeholder)
                                        .foregroundColor(WinampPalette.lcdGreenDim))
                    } else {
                        TextField("", text: text,
                                  prompt: Text(placeholder)
                                    .foregroundColor(WinampPalette.lcdGreenDim))
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(WinampPalette.lcdGreen)
                .padding(.horizontal, 6)
            }
            .frame(height: 22)
            .overlay(BevelOverlay(inset: true))
        }
    }
}

// MARK: - Message bubble

private struct ChatBubble: View {
    let message: ChatMessage
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        switch message.kind {
        case .text(let s):
            LCDText(text: prefix + s, color: textColor, size: 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .textSelection(.enabled)
        case .proposal(let p):
            ProposalCard(proposal: p, vm: vm)
        }
    }

    private var prefix: String {
        switch message.role {
        case .user:      return "▶ "
        case .assistant: return ""
        case .status:    return "· "
        case .error:     return "‼ "
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:      return WinampPalette.lcdAmber
        case .assistant: return WinampPalette.lcdGreen
        case .status:    return WinampPalette.lcdGreenDim
        case .error:     return WinampPalette.lcdRed
        }
    }
}

// MARK: - Proposal approval card

private struct ProposalCard: View {
    let proposal: Proposal
    @ObservedObject var vm: ChatViewModel
    @State private var checked: [Bool]

    init(proposal: Proposal, vm: ChatViewModel) {
        self.proposal = proposal
        self.vm = vm
        self._checked = State(initialValue: proposal.resolved ? proposal.decisions : Array(repeating: true, count: proposal.items.count))
    }

    var body: some View {
        BeveledPanel(inset: true, fill: WinampPalette.lcdBackground) {
            VStack(alignment: .leading, spacing: 6) {
                LCDText(text: proposal.resolved ? "↓ DOWNLOAD PLAN (RESOLVED)" : "↓ DOWNLOAD PLAN — APPROVE?",
                        color: proposal.resolved ? WinampPalette.lcdGreenDim : WinampPalette.lcdAmber,
                        size: 11)

                ForEach(Array(proposal.items.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Button(action: { toggle(idx) }) {
                            Text(checked[idx] ? "[x]" : "[ ]")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(checked[idx] ? WinampPalette.lcdGreen : WinampPalette.lcdGreenDim)
                        }
                        .buttonStyle(.plain)
                        .disabled(proposal.resolved)

                        VStack(alignment: .leading, spacing: 1) {
                            LCDText(text: item.title,
                                    color: rowColor(idx), size: 11)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            LCDText(text: "[\(item.format.uppercased()) · \(item.quality.uppercased())]",
                                    color: WinampPalette.lcdAmber, size: 9)
                            if let note = item.note, !note.isEmpty {
                                LCDText(text: note,
                                        color: WinampPalette.lcdGreenDim, size: 9)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                if !proposal.resolved {
                    HStack(spacing: 6) {
                        Spacer()
                        Button("REJECT ALL") {
                            vm.resolveProposal(proposal.id,
                                               decisions: Array(repeating: false, count: proposal.items.count))
                        }
                        .buttonStyle(WinampButtonStyle(minWidth: 80, height: 18))
                        Button("APPROVE") {
                            vm.resolveProposal(proposal.id, decisions: checked)
                        }
                        .buttonStyle(WinampButtonStyle(
                            tint: WinampPalette.panelLight,
                            labelColor: WinampPalette.lcdGreen,
                            minWidth: 80, height: 18
                        ))
                    }
                } else {
                    LCDText(text: resolvedSummary, color: WinampPalette.lcdGreenDim, size: 9)
                }
            }
        }
    }

    private func toggle(_ idx: Int) {
        guard idx < checked.count else { return }
        checked[idx].toggle()
    }

    private func rowColor(_ idx: Int) -> Color {
        if !proposal.resolved { return WinampPalette.lcdGreen }
        return (idx < proposal.decisions.count && proposal.decisions[idx])
            ? WinampPalette.lcdGreen
            : WinampPalette.lcdGreenDim
    }

    private var resolvedSummary: String {
        let approved = proposal.decisions.filter { $0 }.count
        return "queued \(approved) of \(proposal.items.count)"
    }
}
