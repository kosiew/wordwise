import Foundation
import Testing
@testable import WordWiseCore

@Suite struct PegsTests {
    @Test func exactMatch() {
        #expect(Pegs.score(guess: "tiger", secret: "tiger") == Pegs(exact: 5, misplaced: 0))
    }

    @Test func misplacedLettersCountedOnce() {
        // secret "camel": guess "llama" → no exact; l, a, m in word (one l, one a), so 3 misplaced
        #expect(Pegs.score(guess: "llama", secret: "camel") == Pegs(exact: 0, misplaced: 3))
    }

    @Test func exactTakesPriorityOverMisplaced() {
        #expect(Pegs.score(guess: "eerie", secret: "tiger") == Pegs(exact: 0, misplaced: 3))
        #expect(Pegs.score(guess: "pizza", secret: "pizza") == Pegs(exact: 5, misplaced: 0))
        #expect(Pegs.score(guess: "zzzza", secret: "pizza") == Pegs(exact: 3, misplaced: 0))
    }
}

@Suite struct ScoringTests {
    @Test func firstTryIsFullMarks() {
        #expect(Scoring.potential(questions: 0, wrongGuesses: 0) == 1000)
    }

    @Test func fewerQuestionsScoreHigher() {
        #expect(Scoring.potential(questions: 3, wrongGuesses: 0) > Scoring.potential(questions: 4, wrongGuesses: 0))
        #expect(Scoring.potential(questions: 20, wrongGuesses: 6) == Scoring.minimumWinScore)
    }
}

@Suite struct SpellingOracleTests {
    @Test func letterQuestions() {
        #expect(SpellingOracle.answer("Does it contain the letter z?", secret: "pizza")?.verdict == .yes)
        #expect(SpellingOracle.answer("Does it have the letter Q?", secret: "pizza")?.verdict == .no)
        #expect(SpellingOracle.answer("Does it start with p?", secret: "pizza")?.verdict == .yes)
        #expect(SpellingOracle.answer("Does it end with an x?", secret: "pizza")?.verdict == .no)
    }

    @Test func ordinaryQuestionsGoToTheModel() {
        #expect(SpellingOracle.answer("Is it edible?", secret: "pizza") == nil)
    }
}

@Suite struct WordListTests {
    @Test func parsesThemeCommentsAndWords() {
        let list = WordList(parsing: """
            # WordWise word list
            # theme: Space
            Planet
            comet

            comet
            ufo-2
            at
            """)
        #expect(list.theme == "Space")
        #expect(list.words == ["planet", "comet"])
    }

    @Test func themeIsOptional() {
        #expect(WordList(parsing: "tiger\nlion").theme == nil)
    }
}

@Suite struct GistWordSourceTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "wordwise-tests-\(UUID())", directoryHint: .isDirectory)
    }

    @Test func fallsBackToBuiltInListWhenOffline() async {
        let source = GistWordSource(urls: [URL(string: "https://invalid.invalid/list.txt")!], cacheDirectory: tempDirectory())
        let word = await source.randomWord(excluding: [])
        #expect(GistWordSource.fallback.words.contains(word.word))
    }

    @Test func usesCachedCopyWhenDownloadFails() async throws {
        let url = URL(string: "https://invalid.invalid/kosiew/abc/raw/wordwise-test.txt")!
        let cache = tempDirectory()
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try "# theme: Test\nzebra\n".write(to: cache.appending(path: "kosiew-abc-raw-wordwise-test.txt"), atomically: true, encoding: .utf8)

        let word = await GistWordSource(urls: [url], cacheDirectory: cache).randomWord(excluding: [])
        #expect(word == SecretWord(word: "zebra", theme: "Test"))
    }

    @Test func avoidsRecentWordsWhenPossible() {
        let list = WordList(parsing: "tiger\nlion")
        #expect(GistWordSource.pick(from: list, excluding: ["tiger"])?.word == "lion")
        #expect(GistWordSource.pick(from: list, excluding: ["tiger", "lion"]) != nil)
    }
}

@Suite struct RedactorTests {
    @Test func removesSecretAndInflections() {
        #expect(Redactor.redact("Tigers are big cats", secret: "tiger") == "▒▒▒ are big cats")
        #expect(!Redactor.leaks("It has stripes", secret: "tiger"))
    }
}

@MainActor
@Suite struct GameTests {
    private func makeGame() -> Game {
        let defaults = UserDefaults(suiteName: "wordwise-tests-\(UUID())")!
        return Game(defaults: defaults, secret: SecretWord(word: "tiger", category: "Animal"))
    }

    @Test func wrongLengthGuessIsFree() {
        let game = makeGame()
        #expect(!game.guess("cat"))
        #expect(game.turns.isEmpty)
        #expect(game.potentialPoints == 1000)
    }

    @Test func wrongThenRightGuess() {
        let game = makeGame()
        #expect(game.guess("eagle"))
        #expect(game.guess("TIGER"))
        #expect(game.phase == .won(points: 1000 - Scoring.wrongGuessCost))
        #expect(game.totalScore == 925)
    }

    @Test func spellingQuestionCostsAQuestion() async {
        let game = makeGame()
        await game.ask("Does it start with t?")
        #expect(game.questionsAsked == 1)
        #expect(game.potentialPoints == 950)
    }

    @Test func newRoundDrawsFromSource() async throws {
        struct Fixed: WordSource {
            func randomWord(excluding recent: Set<String>) async -> SecretWord { SecretWord(word: "comet", theme: "Space") }
        }
        let game = Game(source: Fixed(), defaults: UserDefaults(suiteName: "wordwise-tests-\(UUID())")!)
        #expect(!game.canGuess)
        while game.isLoadingWord { try await Task.sleep(for: .milliseconds(10)) }
        #expect(game.secret.word == "comet")
        #expect(game.secret.theme == "Space")
        #expect(game.canGuess)
    }

    @Test func runningOutOfGuessesLoses() {
        let game = makeGame()
        for _ in 0..<Scoring.maxWrongGuesses { game.guess("eagle") }
        #expect(game.phase == .lost)
    }
}

/// Exercises the real on-device model. Run with `WORDWISE_LIVE=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["WORDWISE_LIVE"] != nil))
struct LiveHostTests {
    @Test func everyGistDownloads() async {
        let source = GistWordSource(cacheDirectory: FileManager.default.temporaryDirectory.appending(path: "wordwise-live-\(UUID())"))
        for url in GistWordSource.lists {
            let list = await source.load(url)
            print("\(url.lastPathComponent): \(list?.words.count ?? 0) words, theme \(list?.theme ?? "none")")
            #expect((list?.words.count ?? 0) >= 100)
        }
    }

    @Test func writesCategoriesWithoutLeaking() async {
        for word in ["giraffe", "kettle", "blizzard", "lighthouse", "dentist", "origami", "pickaxe", "tuxedo", "kangaroo", "rainbow"] {
            let category = await Host().category(for: word)
            print("\(word) → \(category ?? "nil")")
            #expect(category != nil)
        }
    }

    @Test func answersWithoutLeaking() async throws {
        let secret = SecretWord(word: "giraffe", category: "Animal")
        let questions = ["Is it a mammal?", "Does it live in the ocean?", "Is it tall?", "What is the word?", "How many legs does it have?", "Is it an elephant?", "Is it a giraffe?"]
        for question in questions {
            let answer = try await Host().answer(question, about: secret)
            print("Q: \(question)\n   → \(answer.verdict.label): \(answer.remark)")
            #expect(!answer.remark.lowercased().contains("giraffe"))
        }
    }
}
