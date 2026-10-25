import Foundation
import Observation

public enum Turn: Identifiable, Equatable, Sendable {
    case question(id: UUID = UUID(), text: String, answer: HostAnswer)
    case guess(id: UUID = UUID(), word: String, pegs: Pegs)

    public var id: UUID {
        switch self {
        case .question(let id, _, _), .guess(let id, _, _): id
        }
    }
}

public enum Phase: Equatable, Sendable {
    case playing
    case won(points: Int)
    case lost
}

@MainActor
@Observable
public final class Game {
    public private(set) var secret: SecretWord
    public private(set) var turns: [Turn] = []
    public private(set) var phase: Phase = .playing
    public private(set) var isThinking = false
    public private(set) var isLoadingCategory = false
    public var notice: String?

    public private(set) var totalScore: Int
    public private(set) var bestScore: Int

    @ObservationIgnored private let host: Host
    @ObservationIgnored private let defaults: UserDefaults

    public init(host: Host = Host(), defaults: UserDefaults = .standard, secret: SecretWord? = nil) {
        self.host = host
        self.defaults = defaults
        self.secret = secret ?? SecretWord(word: WordBank.random())
        self.totalScore = defaults.integer(forKey: "totalScore")
        self.bestScore = defaults.integer(forKey: "bestScore")
        if secret == nil { loadCategory() }
    }

    public var questionsAsked: Int {
        turns.filter { if case .question(_, _, let a) = $0 { a.verdict.isCharged } else { false } }.count
    }

    public var wrongGuesses: Int {
        turns.filter { if case .guess(_, let w, _) = $0 { w != secret.word } else { false } }.count
    }

    public var potentialPoints: Int {
        Scoring.potential(questions: questionsAsked, wrongGuesses: wrongGuesses)
    }

    public var questionsLeft: Int { Scoring.maxQuestions - questionsAsked }
    public var guessesLeft: Int { Scoring.maxWrongGuesses - wrongGuesses }
    public var canAsk: Bool { phase == .playing && !isThinking && questionsLeft > 0 }

    public func ask(_ raw: String) async {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAsk, !question.isEmpty else { return }
        notice = nil
        isThinking = true
        defer { isThinking = false }
        do {
            let answer = try await host.answer(question, about: secret)
            turns.append(.question(text: question, answer: answer))
        } catch {
            notice = error.localizedDescription
        }
    }

    /// Returns false (and sets a notice) when the guess was rejected without costing anything.
    @discardableResult
    public func guess(_ raw: String) -> Bool {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard phase == .playing, !word.isEmpty else { return false }
        guard word.allSatisfy(\.isLetter) else {
            notice = "Guesses must be a single word, letters only."
            return false
        }
        guard word.count == secret.word.count else {
            notice = "The secret word has \(secret.word.count) letters — your guess has \(word.count)."
            return false
        }
        notice = nil
        turns.append(.guess(word: word, pegs: Pegs.score(guess: word, secret: secret.word)))

        if word == secret.word {
            let points = potentialPoints
            phase = .won(points: points)
            record(points)
        } else if guessesLeft <= 0 {
            phase = .lost
        }
        return true
    }

    public func giveUp() {
        guard phase == .playing else { return }
        phase = .lost
    }

    public func newRound() {
        secret = SecretWord(word: WordBank.random(excluding: secret.word))
        turns = []
        phase = .playing
        notice = nil
        loadCategory()
    }

    private func loadCategory() {
        let word = secret.word
        isLoadingCategory = true
        Task {
            let category = await host.category(for: word)
            // Ignore a late reply if the player has already moved on to another round.
            guard secret.word == word else { return }
            secret.category = category
            isLoadingCategory = false
        }
    }

    private func record(_ points: Int) {
        totalScore += points
        bestScore = max(bestScore, points)
        defaults.set(totalScore, forKey: "totalScore")
        defaults.set(bestScore, forKey: "bestScore")
    }
}
