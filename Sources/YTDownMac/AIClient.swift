import Foundation

/// Thin OpenAI-compatible chat completions client. Targets any provider that
/// exposes the `/chat/completions` endpoint (OpenAI, OpenRouter, Together,
/// Groq, Anthropic via gateway, local Ollama in OpenAI mode, etc.).
struct AIClient {
    let apiKey: String
    let baseURL: String
    let model: String

    struct Response: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: ResponseMessage
            let finish_reason: String?
        }
        struct ResponseMessage: Decodable {
            let role: String
            let content: String?
            let tool_calls: [ToolCall]?
        }
        struct ToolCall: Decodable {
            let id: String
            let type: String
            let function: Function
        }
        struct Function: Decodable {
            let name: String
            let arguments: String
        }
    }

    func chat(messages: [[String: Any]], tools: [[String: Any]]) async throws -> Response {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/chat/completions") else {
            throw AIError.badURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.transport("non-HTTP response")
        }
        guard 200..<300 ~= http.statusCode else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AIError.api(status: http.statusCode, body: text)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum AIError: LocalizedError {
    case badURL
    case transport(String)
    case api(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid base URL — check PREFS"
        case .transport(let m): return m
        case .api(let s, let b):
            if let trimmed = b.split(separator: "\n").first.map(String.init) {
                return "API error \(s): \(trimmed)"
            }
            return "API error \(s)"
        }
    }
}
