import Foundation

enum MediaFormat: String, CaseIterable, Identifiable, Codable {
    case mp4
    case webm
    case mkv
    case mp3
    case m4a
    case opus
    case wav

    var id: String { rawValue }
    var isAudio: Bool {
        switch self {
        case .mp3, .m4a, .opus, .wav: return true
        case .mp4, .webm, .mkv: return false
        }
    }
    var label: String { rawValue.uppercased() }
}

enum Quality: String, CaseIterable, Identifiable, Codable {
    case best
    case q2160
    case q1440
    case q1080
    case q720
    case q480
    case q360
    case audio320
    case audio256
    case audio192
    case audio128

    var id: String { rawValue }

    var label: String {
        switch self {
        case .best:     return "BEST"
        case .q2160:    return "2160p"
        case .q1440:    return "1440p"
        case .q1080:    return "1080p"
        case .q720:     return "720p"
        case .q480:     return "480p"
        case .q360:     return "360p"
        case .audio320: return "320 KBPS"
        case .audio256: return "256 KBPS"
        case .audio192: return "192 KBPS"
        case .audio128: return "128 KBPS"
        }
    }

    var heightLimit: Int? {
        switch self {
        case .q2160: return 2160
        case .q1440: return 1440
        case .q1080: return 1080
        case .q720:  return 720
        case .q480:  return 480
        case .q360:  return 360
        default:     return nil
        }
    }

    var audioKbps: Int? {
        switch self {
        case .audio320: return 320
        case .audio256: return 256
        case .audio192: return 192
        case .audio128: return 128
        default:        return nil
        }
    }

    static func qualities(for format: MediaFormat) -> [Quality] {
        if format.isAudio {
            return [.best, .audio320, .audio256, .audio192, .audio128]
        } else {
            return [.best, .q2160, .q1440, .q1080, .q720, .q480, .q360]
        }
    }
}

enum DownloadStatus: Equatable {
    case queued
    case running
    case completed
    case failed(String)
    case canceled

    var label: String {
        switch self {
        case .queued:    return "QUEUED"
        case .running:   return "RUN"
        case .completed: return "DONE"
        case .failed:    return "FAIL"
        case .canceled:  return "CXLD"
        }
    }
}

/// Status of the post-download iTunes Search API metadata enrichment pass.
/// Only meaningful on audio downloads; video stays at `.notApplicable`.
enum MetadataStatus: Equatable {
    case notApplicable
    case enriching
    case enriched(String)
    case failed(String)

    var shortLabel: String {
        switch self {
        case .notApplicable: return ""
        case .enriching:     return "TAG…"
        case .enriched:      return "♪"
        case .failed:        return "TAG✗"
        }
    }
}

final class DownloadItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: String
    let format: MediaFormat
    let quality: Quality
    let createdAt = Date()

    @Published var title: String
    @Published var status: DownloadStatus = .queued
    @Published var progress: Double = 0      // 0...1
    @Published var speed: String = ""
    @Published var eta: String = ""
    @Published var totalSize: String = ""
    @Published var outputPath: String = ""
    @Published var lastLine: String = ""
    @Published var metadataStatus: MetadataStatus = .notApplicable

    init(url: String, format: MediaFormat, quality: Quality, title: String? = nil) {
        self.url = url
        self.format = format
        self.quality = quality
        self.title = title ?? url
    }
}
