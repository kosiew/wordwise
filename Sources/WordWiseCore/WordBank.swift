import Foundation

/// A secret word plus the hint shown to the player. The category is written by the on-device model
/// once the round starts, so it's nil until that arrives (or if the model is unavailable).
public struct SecretWord: Equatable, Sendable {
    public let word: String
    public var category: String?

    public init(word: String, category: String? = nil) {
        self.word = word.lowercased()
        self.category = category
    }
}

public enum WordBankError: LocalizedError {
    case noWords(URL)

    public var errorDescription: String? {
        switch self {
        case .noWords(let url): "“\(url.lastPathComponent)” has no usable words. Put one word per line, letters only."
        }
    }
}

/// Secret words read from a plain-text file: one word per line, `#` starts a comment line.
/// The app ships with `words.txt`; any other file in the same format can be swapped in.
public struct WordBank: Equatable, Sendable {
    public let words: [String]
    /// The file the words came from, or nil for the built-in list.
    public let source: URL?

    public static let builtInURL = Bundle.module.url(forResource: "words", withExtension: "txt")!

    public static var builtIn: WordBank {
        // The bundled file is checked by tests, so failing to read it is a packaging bug.
        try! WordBank(contentsOf: builtInURL, source: nil)
    }

    public init(contentsOf url: URL) throws {
        try self.init(contentsOf: url, source: url)
    }

    private init(contentsOf url: URL, source: URL?) throws {
        let words = Self.parse(try String(contentsOf: url, encoding: .utf8))
        guard !words.isEmpty else { throw WordBankError.noWords(url) }
        self.words = words
        self.source = source
    }

    public init(words: [String]) {
        self.words = words
        self.source = nil
    }

    /// Keeps lines that are a single word of three or more letters, lowercased and without duplicates.
    public static func parse(_ text: String) -> [String] {
        var seen: Set<String> = []
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let word = line.trimmingCharacters(in: .whitespaces).lowercased()
            guard !word.hasPrefix("#"), word.count >= 3, word.allSatisfy({ ("a"..."z").contains($0) }),
                  seen.insert(word).inserted
            else { return nil }
            return word
        }
    }

    public func random(excluding previous: String? = nil) -> String {
        let pool = words.filter { $0 != previous }
        return (pool.isEmpty ? words : pool).randomElement()!
    }
}

/// A word-list file offered in the Word List menu.
public struct WordListFile: Identifiable, Hashable, Sendable {
    public let url: URL
    /// The file name as a title, e.g. "fantasy.txt" → "Fantasy", "board-games.txt" → "Board Games".
    public var name: String {
        url.deletingPathExtension().lastPathComponent
            .replacing("-", with: " ").replacing("_", with: " ")
            .capitalized
    }
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }
}

/// Finds the `.txt` word lists the app ships with and the ones the player has added.
public enum WordListLibrary {
    /// Lists packaged with the app (`Resources/wordlists`).
    public static let bundledFolder = Bundle.module.url(forResource: "wordlists", withExtension: nil)!

    /// Drop `.txt` files here to add lists without rebuilding the app.
    public static let userFolder = URL.applicationSupportDirectory
        .appending(path: "WordWise/Lists", directoryHint: .isDirectory)

    public static func scan(_ folder: URL) -> [WordListFile] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "txt" }
            .map(WordListFile.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
