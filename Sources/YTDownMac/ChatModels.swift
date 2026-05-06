import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: Role
    var kind: Kind

    init(id: UUID = UUID(), role: Role, kind: Kind) {
        self.id = id
        self.role = role
        self.kind = kind
    }

    enum Role: Equatable {
        case user
        case assistant
        case status   // little system note, e.g. "searching YouTube…"
        case error
    }

    enum Kind: Equatable {
        case text(String)
        case proposal(Proposal)
    }
}

struct Proposal: Identifiable, Equatable {
    let id: UUID
    var items: [ProposedDownload]
    var resolved: Bool
    var decisions: [Bool]   // index-aligned with items

    init(items: [ProposedDownload]) {
        self.id = UUID()
        self.items = items
        self.resolved = false
        self.decisions = Array(repeating: true, count: items.count) // default: all approved
    }
}

struct ProposedDownload: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let url: String
    let format: String   // "mp3", "mp4", "m4a", …
    let quality: String  // "best", "1080p", "320", …
    let note: String?

    enum CodingKeys: String, CodingKey {
        case title, url, format, quality, note
    }
}
