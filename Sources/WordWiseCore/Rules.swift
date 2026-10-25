import Foundation

/// Mastermind-style feedback for a guess: letters in the right spot, and right letters in the wrong spot.
public struct Pegs: Equatable, Sendable {
    public let exact: Int
    public let misplaced: Int

    public init(exact: Int, misplaced: Int) {
        self.exact = exact
        self.misplaced = misplaced
    }

    public static func score(guess: String, secret: String) -> Pegs {
        let g = Array(guess.lowercased())
        let s = Array(secret.lowercased())
        var exact = 0
        var leftoverGuess: [Character: Int] = [:]
        var leftoverSecret: [Character: Int] = [:]
        for i in 0..<max(g.count, s.count) {
            let gc = i < g.count ? g[i] : nil
            let sc = i < s.count ? s[i] : nil
            if let gc, gc == sc {
                exact += 1
            } else {
                if let gc { leftoverGuess[gc, default: 0] += 1 }
                if let sc { leftoverSecret[sc, default: 0] += 1 }
            }
        }
        let misplaced = leftoverGuess.reduce(0) { $0 + min($1.value, leftoverSecret[$1.key] ?? 0) }
        return Pegs(exact: exact, misplaced: misplaced)
    }
}

public enum Scoring {
    public static let base = 1000
    public static let questionCost = 50
    public static let wrongGuessCost = 75
    public static let minimumWinScore = 50
    public static let maxQuestions = 20
    public static let maxWrongGuesses = 6

    /// Points the player would earn by solving it right now.
    public static func potential(questions: Int, wrongGuesses: Int) -> Int {
        max(minimumWinScore, base - questions * questionCost - wrongGuesses * wrongGuessCost)
    }
}

public enum Verdict: String, Sendable, CaseIterable {
    // Raw values are what the model sees in the schema, so they're spelled out to be self-explanatory.
    case yes, no, sometimes, unknown
    case notYesNo = "not_a_yes_no_question"

    public var label: String {
        switch self {
        case .yes: "Yes"
        case .no: "No"
        case .sometimes: "Sometimes"
        case .unknown: "Can't say"
        case .notYesNo: "Ask a yes/no question"
        }
    }

    /// Whether answering this costs the player a question.
    public var isCharged: Bool { self != .notYesNo }
}

public struct HostAnswer: Equatable, Sendable {
    public let verdict: Verdict
    public let remark: String

    public init(verdict: Verdict, remark: String) {
        self.verdict = verdict
        self.remark = remark
    }
}

/// Spelling questions are answered deterministically: small language models are unreliable at counting letters,
/// and the player deserves a correct answer for the points they spend.
public enum SpellingOracle {
    public static func answer(_ question: String, secret: String) -> HostAnswer? {
        let q = question.lowercased()
        let word = secret.lowercased()

        if let letter = capture(#"\b(?:start|starts|begin|begins)\s+with\s+(?:the\s+letter\s+|an?\s+)?["']?([a-z])\b"#, in: q) {
            return yesNo(word.first == letter, "About the first letter.")
        }
        if let letter = capture(#"\b(?:end|ends)\s+with\s+(?:the\s+letter\s+|an?\s+)?["']?([a-z])\b"#, in: q) {
            return yesNo(word.last == letter, "About the last letter.")
        }
        if let letter = capture(#"\bletter\s+["']?([a-z])\b"#, in: q) {
            let count = word.filter { $0 == letter }.count
            return HostAnswer(
                verdict: count > 0 ? .yes : .no,
                remark: count > 1 ? "It appears \(count) times." : "Spelling question."
            )
        }
        return nil
    }

    private static func yesNo(_ value: Bool, _ remark: String) -> HostAnswer {
        HostAnswer(verdict: value ? .yes : .no, remark: remark)
    }

    private static func capture(_ pattern: String, in text: String) -> Character? {
        guard let regex = try? Regex(pattern),
              let match = text.firstMatch(of: regex),
              match.count > 1,
              let sub = match[1].substring
        else { return nil }
        return sub.first
    }
}

public enum Redactor {
    /// Removes any form of the secret word from model output so the host can never give it away.
    public static func redact(_ text: String, secret: String) -> String {
        let stem = secret.count > 4 ? String(secret.dropLast()) : secret
        let pattern = "(?i)\\b\\w*\(NSRegularExpression.escapedPattern(for: stem))\\w*\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "▒▒▒")
    }

    public static func leaks(_ text: String, secret: String) -> Bool {
        redact(text, secret: secret) != text
    }
}
