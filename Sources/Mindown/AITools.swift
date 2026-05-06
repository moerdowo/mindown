import Foundation

/// Tool definitions surfaced to the OpenAI-compatible model, plus the host-
/// side implementations of the functions the model can call.
enum AITools {

    static let definitions: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "search_youtube",
                "description": """
                Search YouTube via yt-dlp. Returns up to `limit` candidate \
                videos with title, channel, duration in seconds, and the \
                canonical webpage URL. Use this to find URLs for downloads.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": """
                            Search query, e.g. \"Taylor Swift Anti-Hero \
                            official audio\".
                            """
                        ],
                        "limit": [
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 10,
                            "description": "Number of results, default 5."
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "propose_downloads",
                "description": """
                Surface a list of proposed downloads to the user for \
                approval. The user reviews each item, ticks/unticks them, \
                and confirms. Approved items are queued automatically. \
                Returns counts and per-item approval status. Always call \
                this BEFORE assuming a download has happened.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "items": [
                            "type": "array",
                            "minItems": 1,
                            "items": [
                                "type": "object",
                                "properties": [
                                    "url":   ["type": "string", "description": "Canonical YouTube URL."],
                                    "title": ["type": "string", "description": "Human-readable title (artist - song)."],
                                    "format": [
                                        "type": "string",
                                        "enum": ["mp3", "m4a", "opus", "wav", "mp4", "webm", "mkv"]
                                    ],
                                    "quality": [
                                        "type": "string",
                                        "description": """
                                        For video: best, 2160p, 1440p, 1080p, \
                                        720p, 480p, 360p. For audio: best, \
                                        320, 256, 192, 128 (kbps).
                                        """
                                    ],
                                    "note": [
                                        "type": "string",
                                        "description": "Short justification, optional."
                                    ]
                                ],
                                "required": ["url", "title", "format", "quality"]
                            ]
                        ]
                    ],
                    "required": ["items"]
                ]
            ]
        ]
    ]

    // MARK: - search_youtube

    static func searchYouTube(query: String, limit: Int, ytDlpPath: String) -> String {
        guard !ytDlpPath.isEmpty,
              FileManager.default.isExecutableFile(atPath: ytDlpPath) else {
            return errorJSON("yt-dlp not configured — set its path in PREFS")
        }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return errorJSON("empty query") }
        let bounded = max(1, min(limit, 10))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "ytsearch\(bounded):\(trimmedQuery)",
            "--print", "%(id)s|||%(title)s|||%(uploader)s|||%(duration)s|||%(webpage_url)s",
            "--skip-download",
            "--no-warnings",
            "--quiet",
            "--ignore-errors",
            "--flat-playlist"
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return errorJSON("could not run yt-dlp: \(error.localizedDescription)")
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""

        let results: [[String: Any]] = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 5 else { return nil }
                let durationSec = Int(Double(parts[3]) ?? 0)
                return [
                    "id": parts[0],
                    "title": parts[1],
                    "channel": parts[2],
                    "duration_seconds": durationSec,
                    "url": parts[4]
                ]
            }

        let payload: [String: Any] = ["query": trimmedQuery, "results": results]
        return jsonString(payload) ?? errorJSON("encoding failure")
    }

    // MARK: - format / quality parsing

    static func parseFormat(_ s: String) -> MediaFormat {
        return MediaFormat(rawValue: s.lowercased()) ?? .mp3
    }

    static func parseQuality(_ s: String, isAudio: Bool) -> Quality {
        let lower = s.lowercased()
            .replacingOccurrences(of: "kbps", with: "")
            .replacingOccurrences(of: "k", with: "")
            .replacingOccurrences(of: "p", with: "")
            .trimmingCharacters(in: .whitespaces)
        switch lower {
        case "best", "":           return .best
        case "2160", "4k":         return isAudio ? .best : .q2160
        case "1440":               return isAudio ? .best : .q1440
        case "1080":               return isAudio ? .best : .q1080
        case "720":                return isAudio ? .best : .q720
        case "480":                return isAudio ? .best : .q480
        case "360":                return isAudio ? .best : .q360
        case "320":                return isAudio ? .audio320 : .best
        case "256":                return isAudio ? .audio256 : .best
        case "192":                return isAudio ? .audio192 : .best
        case "128":                return isAudio ? .audio128 : .best
        default:                   return .best
        }
    }

    // MARK: - JSON helpers

    private static func jsonString(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func errorJSON(_ message: String) -> String {
        return jsonString(["error": message]) ?? "{\"error\":\"unknown\"}"
    }
}
