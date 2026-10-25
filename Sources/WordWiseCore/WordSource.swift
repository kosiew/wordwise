import Foundation

/// A secret word plus the hints shown to the player. `theme` comes from the word list the word was drawn
/// from; `category` is written by the on-device model once the round starts (nil until then, or if unavailable).
public struct SecretWord: Equatable, Sendable {
    public let word: String
    public let theme: String?
    public var category: String?

    public init(word: String, theme: String? = nil, category: String? = nil) {
        self.word = word.lowercased()
        self.theme = theme
        self.category = category
    }
}

/// A word list in the gist format: one word per line, `#` comments, and an optional `# theme: Name` line.
public struct WordList: Equatable, Sendable {
    public let theme: String?
    public let words: [String]

    public init(parsing text: String) {
        var theme: String?
        var words: [String] = []
        var seen: Set<String> = []
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let comment = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if comment.lowercased().hasPrefix("theme:") {
                    theme = comment.dropFirst("theme:".count).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            let word = trimmed.lowercased()
            guard word.count >= 3, word.allSatisfy({ ("a"..."z").contains($0) }), seen.insert(word).inserted
            else { continue }
            words.append(word)
        }
        self.theme = theme?.isEmpty == true ? nil : theme
        self.words = words
    }
}

public protocol WordSource: Sendable {
    func randomWord(excluding recent: Set<String>) async -> SecretWord
}

/// Draws words from word lists hosted as GitHub gists. Each round picks a random gist; if it can't be
/// downloaded, the last copy cached on disk is used, then the other gists, then a small built-in list.
public struct GistWordSource: WordSource {
    public static let lists: [URL] = [
        "ddfe472e5c617eab6e94181e6d8a9862/raw/wordwise-general.txt",
        "51625e03ef860669a391700fd46c3fa2/raw/wordwise-space.txt",
        "6a16f1595a2c55c4cb936ad8b024f09d/raw/wordwise-ocean.txt",
        "c831fd72963003daf078f73f097c0430/raw/wordwise-kitchen.txt",
        "a9a316311b127e5dc6809f1a6d70072a/raw/wordwise-sports.txt",
        "7da797202fb49a5e5dad212df0d627fc/raw/wordwise-music.txt",
        "2390249d88cb010e65f70ab4b9e4f940/raw/wordwise-fantasy.txt",
        "1ef2ec8dd19f2c7c6e8595f455593ffb/raw/wordwise-garden.txt",
        "03f35398b71889511a79d7f30bc13018/raw/wordwise-science.txt",
        "bcfdd5cf460fc3075fbbe10b8807c314/raw/wordwise-travel.txt",
        "7b4e0f2286f9fead504ec1bc2ff7802c/raw/wordwise-farm.txt",
    ].map { URL(string: "https://gist.githubusercontent.com/kosiew/\($0)")! }

    /// Used only when no gist has ever been downloaded and the network is unreachable.
    static let fallback = WordList(parsing: [
        "tiger", "penguin", "giraffe", "banana", "pizza", "candle", "mirror", "castle", "library", "rocket",
        "guitar", "rainbow", "volcano", "umbrella", "bicycle", "dragon", "teapot", "lighthouse", "cactus", "butterfly",
    ].joined(separator: "\n"))

    let urls: [URL]
    let session: URLSession
    let cacheDirectory: URL

    public init(
        urls: [URL] = Self.lists,
        session: URLSession = .shared,
        cacheDirectory: URL = URL.applicationSupportDirectory.appending(path: "WordWise/Lists", directoryHint: .isDirectory)
    ) {
        self.urls = urls
        self.session = session
        self.cacheDirectory = cacheDirectory
    }

    public func randomWord(excluding recent: Set<String>) async -> SecretWord {
        for url in urls.shuffled() {
            if let list = await load(url), let word = Self.pick(from: list, excluding: recent) {
                return word
            }
        }
        return Self.pick(from: Self.fallback, excluding: recent) ?? SecretWord(word: Self.fallback.words[0])
    }

    static func pick(from list: WordList, excluding recent: Set<String>) -> SecretWord? {
        let fresh = list.words.filter { !recent.contains($0) }
        guard let word = (fresh.isEmpty ? list.words : fresh).randomElement() else { return nil }
        return SecretWord(word: word, theme: list.theme)
    }

    func load(_ url: URL) async -> WordList? {
        // One cache file per gist, e.g. "kosiew-<gist id>-raw-wordwise-space.txt".
        let cacheFile = cacheDirectory.appending(path: url.pathComponents.dropFirst().joined(separator: "-"))
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.cachePolicy = .reloadRevalidatingCacheData
        if let (data, response) = try? await session.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let text = String(data: data, encoding: .utf8) {
            let list = WordList(parsing: text)
            if !list.words.isEmpty {
                try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try? data.write(to: cacheFile, options: .atomic)
                return list
            }
        }
        guard let cached = try? String(contentsOf: cacheFile, encoding: .utf8) else { return nil }
        let list = WordList(parsing: cached)
        return list.words.isEmpty ? nil : list
    }
}
