import SwiftUI
import WordWiseCore

enum Mode: String, CaseIterable {
    case ask = "Ask"
    case guess = "Guess"
}

struct ContentView: View {
    @Bindable var game: Game
    @Stored private var mode: Mode = .ask
    @Stored private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            log
            Divider()
            footer
        }
        .onAppear { inputFocused = true }
        .onChange(of: game.secret.word) { input = ""; mode = .ask; inputFocused = true }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Group {
                    if game.isLoadingCategory {
                        Label("Thinking of a hint…", systemImage: "tag")
                    } else {
                        Label(game.secret.category ?? "Mystery word", systemImage: "tag")
                    }
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                Spacer()
                Text("Total \(game.totalScore) · Best \(game.bestScore)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(Array(game.secret.word.enumerated()), id: \.offset) { position, letter in
                    let bought = game.revealedPositions.contains(position)
                    let vowel = game.vowelPositions?.contains(position) == true
                    Text(isRevealed || bought ? String(letter).uppercased() : " ")
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(bought ? Color.accentColor : .primary)
                        .frame(width: 38, height: 44)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                        .background(vowel ? Color.orange.opacity(0.25) : .clear, in: .rect(cornerRadius: 6))
                        .overlay(alignment: .bottom) {
                            if vowel {
                                Text("vowel")
                                    .font(.system(size: 8).weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.bottom, 2)
                            }
                        }
                        .overlay {
                            if bought { RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2) }
                        }
                        .overlay(alignment: .topLeading) {
                            Text("\(position + 1)")
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                                .padding(.top, 2)
                        }
                }
            }
            .animation(.spring, value: isRevealed)
            .animation(.spring, value: game.revealedPositions)
            .animation(.spring, value: game.vowelPositions)

            HStack(spacing: 24) {
                stat("Points available", "\(game.potentialPoints)", tint: .accentColor)
                stat("Questions left", "\(game.questionsLeft)")
                stat("Guesses left", "\(game.guessesLeft)")
                stat("Reveals left", "\(game.revealsLeft)")
            }
        }
        .padding()
    }

    private var isRevealed: Bool { game.phase != .playing }

    private func stat(_ title: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .animation(.default, value: value)
    }

    // MARK: Log

    private var log: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if game.turns.isEmpty {
                        intro
                    }
                    ForEach(game.turns) { turn in
                        TurnRow(turn: turn).id(turn.id)
                    }
                    if game.isThinking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("The host is thinking…").foregroundStyle(.secondary)
                        }
                        .id("thinking")
                    }
                    outcome
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: game.turns.count) {
                withAnimation { proxy.scrollTo(game.turns.last?.id, anchor: .bottom) }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("I'm thinking of a \(game.secret.word.count)-letter word.").font(.headline)
            Text("Ask yes/no questions — each costs \(Scoring.questionCost) points. Or guess the word: a wrong guess costs \(Scoring.wrongGuessCost) points and tells you how many letters are in the right spot (●) or in the word but misplaced (○). Stuck? Reveal a letter for \(Scoring.revealCost) points, or see where the vowels are for \(Scoring.vowelRevealCost).")
                .foregroundStyle(.secondary)
            Text("Word list: \(game.wordBank.source?.lastPathComponent ?? "built-in") (\(game.wordBank.words.count) words) — change it in the Word List menu")
                .font(.caption)
                .foregroundStyle(.tertiary)
            if let reason = Host.unavailabilityReason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var outcome: some View {
        switch game.phase {
        case .playing:
            EmptyView()
        case .won(let points):
            banner("Solved it! +\(points) points", systemImage: "trophy.fill", tint: .green)
        case .lost:
            banner("The word was \(game.secret.word.uppercased())", systemImage: "flag.fill", tint: .orange)
        }
    }

    private func banner(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(.headline).foregroundStyle(tint)
            Spacer()
            Button("New Round") { game.newRound() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 10))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notice = game.notice {
                Label(notice, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                TextField(placeholder, text: $input)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit(submit)

                Button(mode == .ask ? "Ask" : "Guess", action: submit)
                    .disabled(!canSubmit)
            }
            HStack {
                Button("Reveal a Letter (−\(Scoring.revealCost))") { game.revealLetter() }
                    .buttonStyle(.link)
                    .disabled(!game.canReveal)
                    .keyboardShortcut("r")
                    .help("Shows one hidden letter in its place. Up to \(Scoring.maxReveals(forLength: game.secret.word.count)) per word.")
                Button("Reveal Vowel Positions (−\(Scoring.vowelRevealCost))") { game.revealVowels() }
                    .buttonStyle(.link)
                    .disabled(!game.canRevealVowels)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .help("Marks which boxes hold a vowel (A, E, I, O, U) without saying which. Once per word.")
                Spacer()
                Button("Give Up", role: .destructive) { game.giveUp() }
                    .buttonStyle(.link)
                    .disabled(game.phase != .playing)
            }
        }
        .padding()
        .disabled(game.phase != .playing)
    }

    private var placeholder: String {
        switch mode {
        case .ask: game.questionsLeft > 0 ? "Is it bigger than a breadbox?" : "No questions left — make a guess"
        case .guess: "Your \(game.secret.word.count)-letter guess"
        }
    }

    private var canSubmit: Bool {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return mode == .guess ? game.phase == .playing : game.canAsk
    }

    private func submit() {
        guard canSubmit else { return }
        let text = input
        switch mode {
        case .ask:
            input = ""
            Task { await game.ask(text) }
        case .guess:
            if game.guess(text) { input = "" }
        }
        inputFocused = true
    }
}

struct TurnRow: View {
    let turn: Turn

    var body: some View {
        switch turn {
        case .question(_, let text, let answer):
            VStack(alignment: .leading, spacing: 4) {
                Text(text).fontWeight(.medium)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(answer.verdict.label)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(color(for: answer.verdict).opacity(0.18), in: .capsule)
                        .foregroundStyle(color(for: answer.verdict))
                    if !answer.remark.isEmpty {
                        Text(answer.remark).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 8))

        case .guess(_, let word, let pegs):
            HStack(spacing: 12) {
                Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
                Text(word.uppercased()).font(.body.monospaced().weight(.semibold)).tracking(2)
                Spacer()
                Text(String(repeating: "●", count: pegs.exact) + String(repeating: "○", count: pegs.misplaced))
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("\(pegs.exact) exact · \(pegs.misplaced) misplaced")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.background.secondary, in: .rect(cornerRadius: 8))

        case .reveal(_, let position, let letter):
            HStack(spacing: 12) {
                Image(systemName: "eye").foregroundStyle(Color.accentColor)
                Text("Letter \(position + 1) is \(String(letter).uppercased())").fontWeight(.medium)
                Spacer()
                Text("−\(Scoring.revealCost) points").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.background.secondary, in: .rect(cornerRadius: 8))

        case .vowels(_, let positions):
            HStack(spacing: 12) {
                Image(systemName: "character.textbox").foregroundStyle(.orange)
                Text(vowelSummary(positions)).fontWeight(.medium)
                Spacer()
                Text("−\(Scoring.vowelRevealCost) points").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.background.secondary, in: .rect(cornerRadius: 8))
        }
    }

    private func vowelSummary(_ positions: [Int]) -> String {
        switch positions.count {
        case 0: "No vowels in this word"
        case 1: "The vowel is at position \(positions[0] + 1)"
        default: "Vowels are at positions " + positions.map { "\($0 + 1)" }.formatted(.list(type: .and))
        }
    }

    private func color(for verdict: Verdict) -> Color {
        switch verdict {
        case .yes: .green
        case .no: .red
        case .sometimes: .orange
        case .unknown, .notYesNo: .gray
        }
    }
}
