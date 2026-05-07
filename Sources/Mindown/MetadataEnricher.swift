import Foundation

/// Looks up a finished audio download in Apple's free iTunes Search API and
/// writes the matched track's title / artist / album / year / genre / track
/// number plus the high-resolution cover art into the file via ffmpeg.
enum MetadataEnricher {

    // MARK: - Public entry point

    /// Enrich the given audio file. Safe to await on a background task.
    /// Returns `(applied: Bool, message: String)` so the caller can update
    /// the UI with a short status — `applied=true` means tags were written.
    static func enrich(filePath: String,
                       searchTitle: String,
                       ffmpegPath: String) async -> (applied: Bool, message: String) {
        guard !filePath.isEmpty,
              FileManager.default.fileExists(atPath: filePath) else {
            return (false, "file missing")
        }
        guard FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            return (false, "ffmpeg not configured")
        }

        let cleanQuery = cleanedQuery(searchTitle)
        guard !cleanQuery.isEmpty else { return (false, "empty title") }

        let track: ITunesTrack?
        do {
            track = try await search(query: cleanQuery)
        } catch {
            return (false, "iTunes lookup failed")
        }
        guard let track else { return (false, "no iTunes match") }

        // Run the secondary lookups (album copyright + lyrics + cover art)
        // in parallel — none block each other and total wall-time stays
        // under ~2s on a typical connection.
        async let copyrightTask: String? = {
            guard let cid = track.collectionId else { return nil }
            return await lookupAlbumCopyright(collectionId: cid)
        }()
        async let lyricsTask: String? = {
            guard let artist = track.artistName,
                  let trackName = track.trackName else { return nil }
            let durationSec = track.trackTimeMillis.map { Int(Double($0) / 1000.0) }
            return await fetchLyrics(
                artist: artist,
                track: trackName,
                album: track.collectionName,
                durationSeconds: durationSec
            )
        }()
        async let coverTask: String? = {
            guard let raw = track.artworkUrl100 else { return nil }
            let upscaled = raw
                .replacingOccurrences(of: "100x100bb", with: "1200x1200bb")
                .replacingOccurrences(of: "100x100", with: "1200x1200")
            guard let url = URL(string: upscaled),
                  let data = try? await fetchData(url) else { return nil }
            let tmp = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mindown_cover_\(UUID().uuidString).jpg")
            do {
                try data.write(to: URL(fileURLWithPath: tmp))
                return tmp
            } catch {
                return nil
            }
        }()

        let copyright = await copyrightTask
        let lyrics = await lyricsTask
        let coverPath = await coverTask

        defer {
            if let coverPath {
                try? FileManager.default.removeItem(atPath: coverPath)
            }
        }

        let success = (try? writeTags(file: filePath,
                                      track: track,
                                      coverPath: coverPath,
                                      copyright: copyright,
                                      lyrics: lyrics,
                                      ffmpegPath: ffmpegPath)) != nil

        if success {
            var bits: [String] = []
            if let a = track.artistName, let t = track.trackName {
                bits.append("\(a) — \(t)")
            }
            if lyrics != nil { bits.append("+lyrics") }
            if copyright != nil { bits.append("+©") }
            let summary = bits.joined(separator: " ")
            return (true, summary.isEmpty ? "tagged" : "tagged · \(summary)")
        } else {
            return (false, "ffmpeg tag write failed")
        }
    }

    // MARK: - iTunes Search API

    struct ITunesTrack: Decodable {
        let wrapperType: String?
        let trackName: String?
        let artistName: String?
        let collectionName: String?
        let collectionId: Int?
        let releaseDate: String?      // "2022-10-21T07:00:00Z"
        let primaryGenreName: String?
        let trackNumber: Int?
        let trackCount: Int?
        let discNumber: Int?
        let discCount: Int?
        let artworkUrl100: String?
        let trackTimeMillis: Int?
        /// Only present on collection / album wrappers (iTunes lookup), not
        /// on song search results.
        let copyright: String?
    }

    private struct SearchResponse: Decodable {
        let resultCount: Int
        let results: [ITunesTrack]
    }

    private static func search(query: String) async throws -> ITunesTrack? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term",    value: query),
            URLQueryItem(name: "entity",  value: "song"),
            URLQueryItem(name: "limit",   value: "5"),
            URLQueryItem(name: "country", value: "us")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mindown/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.results.first(where: { $0.trackName != nil })
    }

    /// iTunes Search API doesn't expose copyright on song results — but it
    /// does on album (collection) lookups. Hit `/lookup` with the
    /// collectionId from the matched track to grab "℗ 2022 Republic
    /// Records, …" style strings.
    private static func lookupAlbumCopyright(collectionId: Int) async -> String? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id",     value: String(collectionId)),
            URLQueryItem(name: "entity", value: "album")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mindown/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(SearchResponse.self, from: data)
            return resp.results.first(where: { $0.wrapperType == "collection" })?.copyright
        } catch {
            return nil
        }
    }

    // MARK: - LRCLib (free, no auth) — lyrics

    private struct LRCLibResponse: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
        let instrumental: Bool?
    }

    /// Look up plain-text lyrics for the matched track on LRCLib. Returns
    /// nil for instrumentals, missing tracks, or any HTTP error.
    private static func fetchLyrics(artist: String,
                                    track: String,
                                    album: String?,
                                    durationSeconds: Int?) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name",  value: track)
        ]
        if let album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if let durationSeconds {
            items.append(URLQueryItem(name: "duration", value: String(durationSeconds)))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mindown/1.0 (https://github.com/moerdowo/mindown)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let resp = try JSONDecoder().decode(LRCLibResponse.self, from: data)
            if resp.instrumental == true { return nil }
            let plain = resp.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let plain, !plain.isEmpty { return plain }
            return nil
        } catch {
            return nil
        }
    }

    private static func fetchData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - Title cleanup

    /// Strip common YouTube cruft so the iTunes search query is more likely
    /// to land on the official track. Order matters — we apply each pattern
    /// in turn against the lowercased copy to ignore case.
    static func cleanedQuery(_ raw: String) -> String {
        var s = raw

        let patterns: [String] = [
            #"\(\s*official\s*(music)?\s*(video|audio)\s*\)"#,
            #"\[\s*official\s*(music)?\s*(video|audio)\s*\]"#,
            #"\(\s*lyric[s]?\s*(video)?\s*\)"#,
            #"\[\s*lyric[s]?\s*(video)?\s*\]"#,
            #"\(\s*visualiz(er|ation)\s*\)"#,
            #"\(\s*audio\s*\)"#,
            #"\[\s*audio\s*\]"#,
            #"\(\s*hd\s*\)"#,
            #"\[\s*hd\s*\]"#,
            #"\(\s*4k\s*\)"#,
            #"\(\s*explicit\s*\)"#,
            #"\(\s*radio\s*edit\s*\)"#,
            #"\(\s*remaster(ed)?\s*\d*\s*\)"#,
            #"\bft\.?\b"#,
            #"\bfeat\.?\b"#,
        ]
        for pattern in patterns {
            s = s.replacingOccurrences(of: pattern,
                                       with: " ",
                                       options: [.regularExpression, .caseInsensitive])
        }

        // Topic-style suffixes ("Artist - Topic")
        if let range = s.range(of: #"\s*-\s*topic\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            s.removeSubrange(range)
        }

        // Collapse whitespace.
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - ffmpeg tag write

    private static func writeTags(file: String,
                                  track: ITunesTrack,
                                  coverPath: String?,
                                  copyright: String?,
                                  lyrics: String?,
                                  ffmpegPath: String) throws {
        let inputURL = URL(fileURLWithPath: file)
        let ext = inputURL.pathExtension
        let tempURL = inputURL
            .deletingPathExtension()
            .appendingPathExtension("mindown_tag.\(ext)")

        var args: [String] = ["-y", "-loglevel", "error", "-i", file]
        if let coverPath { args.append(contentsOf: ["-i", coverPath]) }

        // Stream mapping: keep all original streams, append cover as new one.
        args.append(contentsOf: ["-map", "0"])
        if coverPath != nil { args.append(contentsOf: ["-map", "1"]) }

        args.append(contentsOf: ["-c", "copy"])

        // ID3v2.3 plays nicely with most older players (esp. mp3).
        if ext.lowercased() == "mp3" {
            args.append(contentsOf: ["-id3v2_version", "3", "-write_id3v1", "1"])
        }

        // Metadata tags. Use ffmpeg's portable -metadata keys; ffmpeg maps
        // them to the right ID3 frame / iTunes atom for the output container.
        if let title = track.trackName, !title.isEmpty {
            args.append(contentsOf: ["-metadata", "title=\(title)"])
        }
        if let artist = track.artistName, !artist.isEmpty {
            args.append(contentsOf: ["-metadata", "artist=\(artist)"])
            args.append(contentsOf: ["-metadata", "album_artist=\(artist)"])
            // iTunes Search API doesn't expose composer; fall back to the
            // performing artist so the field at least resolves to a real
            // person/group rather than staying empty in the playlist UI.
            args.append(contentsOf: ["-metadata", "composer=\(artist)"])
        }
        if let album = track.collectionName, !album.isEmpty {
            args.append(contentsOf: ["-metadata", "album=\(album)"])
        }
        if let releaseDate = track.releaseDate, releaseDate.count >= 4 {
            let year = String(releaseDate.prefix(4))
            args.append(contentsOf: ["-metadata", "date=\(year)"])
            args.append(contentsOf: ["-metadata", "year=\(year)"])
        }
        if let genre = track.primaryGenreName, !genre.isEmpty {
            args.append(contentsOf: ["-metadata", "genre=\(genre)"])
        }
        if let n = track.trackNumber {
            let value = track.trackCount.map { "\(n)/\($0)" } ?? "\(n)"
            args.append(contentsOf: ["-metadata", "track=\(value)"])
        }
        if let n = track.discNumber {
            let value = track.discCount.map { "\(n)/\($0)" } ?? "\(n)"
            args.append(contentsOf: ["-metadata", "disc=\(value)"])
        }
        if let copyright, !copyright.isEmpty {
            args.append(contentsOf: ["-metadata", "copyright=\(copyright)"])
        }
        if let lyrics, !lyrics.isEmpty {
            // ID3v2 USLT frames key off "lyrics-XXX" with a 3-letter ISO
            // language code; ffmpeg also accepts the bare "lyrics" key for
            // mp4/m4a containers and writes the right atom (©lyr) there.
            args.append(contentsOf: ["-metadata", "lyrics-eng=\(lyrics)"])
            args.append(contentsOf: ["-metadata", "lyrics=\(lyrics)"])
        }

        // Mark the cover stream as attached picture (front cover).
        if coverPath != nil {
            args.append(contentsOf: ["-disposition:v", "attached_pic"])
            args.append(contentsOf: ["-metadata:s:v", "title=Album cover"])
            args.append(contentsOf: ["-metadata:s:v", "comment=Cover (front)"])
        }

        args.append(tempURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = args
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(atPath: tempURL.path)
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "MetadataEnricher",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: msg ?? "ffmpeg exited \(process.terminationStatus)"]
            )
        }

        // Atomic-ish replace: remove original, move tagged file in place.
        try FileManager.default.removeItem(atPath: file)
        try FileManager.default.moveItem(atPath: tempURL.path, toPath: file)
    }
}
