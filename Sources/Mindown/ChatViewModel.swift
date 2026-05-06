import Foundation
import SwiftUI

/// Drives the AI sidebar — keeps the chat transcript, runs OpenAI tool-call
/// loops, executes yt-dlp searches, and dispatches approved downloads back
/// to the existing DownloadManager. The two tools the model can call:
///
/// - `search_youtube(query, limit)` — runs `yt-dlp ytsearch:` to look up
///   candidate videos. Auto-executes (no user prompt).
/// - `propose_downloads(items[])` — surfaces a list of {url, format,
///   quality} proposals as an inline approval card. Suspends the tool call
///   via a CheckedContinuation until the user clicks APPROVE / REJECT, then
///   enqueues the approved subset on `DownloadManager`.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isThinking: Bool = false

    private let manager: DownloadManager
    private let settings: AISettings
    private let appSettings: AppSettings

    private var pending: [UUID: CheckedContinuation<[Bool], Never>] = [:]

    init(manager: DownloadManager,
         settings: AISettings = .shared,
         appSettings: AppSettings = .shared) {
        self.manager = manager
        self.settings = settings
        self.appSettings = appSettings
    }

    // MARK: - Sending

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, settings.isConfigured, !isThinking else { return }
        draft = ""
        send(text)
    }

    private func send(_ text: String) {
        messages.append(ChatMessage(role: .user, kind: .text(text)))
        Task { await runConversation() }
    }

    // MARK: - Conversation loop

    private func runConversation() async {
        isThinking = true
        defer { isThinking = false }

        let client = AIClient(
            apiKey: settings.apiKey,
            baseURL: settings.baseURL,
            model: settings.model
        )

        var apiMessages: [[String: Any]] = [systemMessage()]
        apiMessages.append(contentsOf: transcriptToAPIMessages())

        var iterations = 0
        while iterations < 8 {
            iterations += 1
            do {
                let response = try await client.chat(messages: apiMessages, tools: AITools.definitions)
                guard let choice = response.choices.first else { break }

                if let content = choice.message.content, !content.isEmpty {
                    messages.append(ChatMessage(role: .assistant, kind: .text(content)))
                }

                guard let calls = choice.message.tool_calls, !calls.isEmpty else { break }

                // Append assistant turn (with tool_calls) to the API message log.
                var assistantMsg: [String: Any] = ["role": "assistant"]
                assistantMsg["content"] = choice.message.content ?? ""
                assistantMsg["tool_calls"] = calls.map { tc -> [String: Any] in
                    [
                        "id": tc.id,
                        "type": "function",
                        "function": [
                            "name": tc.function.name,
                            "arguments": tc.function.arguments
                        ]
                    ]
                }
                apiMessages.append(assistantMsg)

                for call in calls {
                    let toolResult = await execute(call)
                    apiMessages.append([
                        "role": "tool",
                        "tool_call_id": call.id,
                        "name": call.function.name,
                        "content": toolResult
                    ])
                }
            } catch {
                messages.append(ChatMessage(role: .error, kind: .text(error.localizedDescription)))
                break
            }
        }
    }

    // MARK: - Tool execution

    private func execute(_ call: AIClient.Response.ToolCall) async -> String {
        let argsData = call.function.arguments.data(using: .utf8) ?? Data("{}".utf8)
        let args = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any] ?? [:]

        switch call.function.name {
        case "search_youtube":
            let query = (args["query"] as? String) ?? ""
            let limit = (args["limit"] as? Int) ?? 5
            messages.append(ChatMessage(
                role: .status,
                kind: .text("searching youtube · \(query)"))
            )
            return await Task.detached { [appSettings] in
                AITools.searchYouTube(query: query, limit: limit, ytDlpPath: appSettings.ytDlpPath)
            }.value

        case "propose_downloads":
            let raw = (args["items"] as? [[String: Any]]) ?? []
            let items: [ProposedDownload] = raw.compactMap { dict in
                guard let url   = dict["url"]   as? String,
                      let title = dict["title"] as? String,
                      let fmt   = dict["format"] as? String,
                      let q     = dict["quality"] as? String
                else { return nil }
                return ProposedDownload(
                    title: title,
                    url: url,
                    format: fmt,
                    quality: q,
                    note: dict["note"] as? String
                )
            }
            return await runProposal(items: items)

        default:
            return "{\"error\":\"unknown tool: \(call.function.name)\"}"
        }
    }

    private func runProposal(items: [ProposedDownload]) async -> String {
        guard !items.isEmpty else {
            return "{\"error\":\"propose_downloads called with empty items\"}"
        }

        let proposal = Proposal(items: items)
        messages.append(ChatMessage(role: .assistant, kind: .proposal(proposal)))

        let decisions: [Bool] = await withCheckedContinuation { cont in
            pending[proposal.id] = cont
        }

        var approved = 0
        for (i, item) in items.enumerated() {
            guard i < decisions.count, decisions[i] else { continue }
            approved += 1
            let format = AITools.parseFormat(item.format)
            let quality = AITools.parseQuality(item.quality, isAudio: format.isAudio)
            manager.enqueue(url: item.url, format: format, quality: quality)
        }

        let report: [String: Any] = [
            "approved_count": approved,
            "rejected_count": items.count - approved,
            "items": items.enumerated().map { i, item -> [String: Any] in
                [
                    "title": item.title,
                    "approved": (i < decisions.count ? decisions[i] : false)
                ]
            }
        ]
        let data = (try? JSONSerialization.data(withJSONObject: report)) ?? Data()
        return String(data: data, encoding: .utf8)
            ?? "{\"approved_count\":\(approved)}"
    }

    /// Called from the proposal card UI when the user makes a decision.
    func resolveProposal(_ proposalId: UUID, decisions: [Bool]) {
        if let idx = messages.firstIndex(where: { msg in
            if case .proposal(let p) = msg.kind { return p.id == proposalId }
            return false
        }) {
            if case .proposal(var p) = messages[idx].kind {
                p.decisions = decisions
                p.resolved = true
                messages[idx].kind = .proposal(p)
            }
        }
        if let cont = pending.removeValue(forKey: proposalId) {
            cont.resume(returning: decisions)
        }
    }

    // MARK: - API message construction

    private func systemMessage() -> [String: Any] {
        let prompt = """
        You are Mindown's media assistant. You help the user find and download \
        songs and videos via the bundled yt-dlp.

        Workflow:
        1. When the user asks for a song, artist, or video, call search_youtube \
           with a clear query. Prefer official channels, official audio, lyric \
           videos, or topic auto-uploads over fan covers and reaction videos. \
           Skip live versions unless the user asks for them.
        2. If the user asks for several songs (e.g. "top 5 from artist X"), use \
           your knowledge of the artist's catalogue to pick titles, then call \
           search_youtube once per title.
        3. After collecting candidates, call propose_downloads with the chosen \
           items. The user must approve before anything is queued.
        4. Default to MP3 audio at "best" quality. Use video (MP4 1080p) only \
           if the user explicitly asks for video / a music video.
        5. Reply briefly. Once propose_downloads returns, give a one-line \
           summary like "queued 3 of 5".

        Allowed formats: mp3, m4a, opus, wav (audio); mp4, webm, mkv (video).
        Allowed qualities: best, 2160p, 1440p, 1080p, 720p, 480p, 360p \
        (video); 320, 256, 192, 128 (audio kbps).
        """
        return ["role": "system", "content": prompt]
    }

    private func transcriptToAPIMessages() -> [[String: Any]] {
        messages.compactMap { m -> [String: Any]? in
            switch (m.role, m.kind) {
            case (.user, .text(let t)):
                return ["role": "user", "content": t]
            case (.assistant, .text(let t)):
                return ["role": "assistant", "content": t]
            case (.assistant, .proposal):
                // Proposals are surfaced via tool_call/tool_result in the
                // current call cycle; we don't replay them on subsequent
                // turns so we skip them here.
                return nil
            default:
                return nil
            }
        }
    }
}
