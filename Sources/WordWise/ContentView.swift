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
                ForEach(Array(game.secret.word.enumerated()), id: \.offset) { _, letter in
                    Text(isRevealed ? String(letter).uppercased() : " ")
                        .font(.title2.weight(.bold).monospaced())
                        .frame(width: 38, height: 44)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                }
            }
            .animation(.spring, value: isRevealed)

            HStack(spacing: 24) {
                stat("Points available", "\(game.potentialPoints)", tint: .accentColor)
                stat("Questions left", "\(game.questionsLeft)")
                stat("Guesses left", "\(game.guessesLeft)")
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
            Text("Ask yes/no questions — each costs \(Scoring.questionCost) points. Or guess the word: a wrong guess costs \(Scoring.wrongGuessCost) points and tells you how many letters are in the right spot (●) or in the word but misplaced (○).")
                .foregroundStyle(.secondary)
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
