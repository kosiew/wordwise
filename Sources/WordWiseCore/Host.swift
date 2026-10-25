import Foundation
import FoundationModels

/// The structured reply the model must produce. Built at runtime rather than with `@Generable`
/// so the package compiles with the Command Line Tools, which don't ship the FoundationModels macros.
enum HostReply {
    static let schema: GenerationSchema = {
        let answer = DynamicGenerationSchema(
            name: "Answer",
            description: "The truthful answer to the player's yes/no question about the secret word. Use not_a_yes_no_question for open questions such as \"what is it?\" or \"how many legs?\".",
            anyOf: Verdict.allCases.map(\.rawValue)
        )
        let reply = DynamicGenerationSchema(name: "HostReply", properties: [
            .init(name: "answer", schema: answer),
            .init(
                name: "remark",
                description: "A short, friendly clarification of at most 12 words. It must never contain, spell, rhyme with, or hint at the letters of the secret word.",
                schema: DynamicGenerationSchema(type: String.self)
            ),
        ])
        return try! GenerationSchema(root: reply, dependencies: [])
    }()
}

public enum HostError: LocalizedError {
    case unavailable(String)
    case refused

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        case .refused: "The host couldn't answer that one. Try rephrasing — no points were spent."
        }
    }
}

/// Answers yes/no questions about the secret word using the on-device Foundation Model.
public struct Host: Sendable {
    public init() {}

    /// A user-facing reason the on-device model can't be used, or nil when it's ready.
    public static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn't support Apple Intelligence, which WordWise needs to answer questions."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings to let the host answer questions."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again in a little while."
        case .unavailable:
            return "The on-device model is unavailable right now."
        }
    }

    /// Asks the model for a short category hint, e.g. "Kitchen utensil". Returns nil if the model is
    /// unavailable or its reply would give the word away, so the round can still be played without a hint.
    public func category(for word: String) async -> String? {
        guard Self.unavailabilityReason == nil else { return nil }
        let session = LanguageModelSession(instructions: """
            You write the category hint for a word-guessing game. Given a word, reply with ONE broad \
            category of one to three words. Never include the word itself, a synonym, or any detail \
            that narrows it to one answer. Reply with the category only — no lists, no explanation.
            Examples:
            Word: tiger → Animal
            Word: spatula → Kitchen utensil
            Word: hurricane → Weather
            Word: violin → Musical instrument
            """)
        guard let reply = try? await session.respond(
            to: "Word: \(word) →",
            options: GenerationOptions(temperature: 0.3)
        ).content else { return nil }

        // Keep only the first item if the model returns a list, since extra items narrow the answer.
        let category = reply
            .split(whereSeparator: { $0.isNewline || $0 == "," || $0 == ";" }).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) ?? ""
        guard !category.isEmpty, category.count <= 32, !Redactor.leaks(category, secret: word) else { return nil }
        return category.prefix(1).uppercased() + category.dropFirst()
    }

    public func answer(_ question: String, about secret: SecretWord) async throws -> HostAnswer {
        if let local = SpellingOracle.answer(question, secret: secret.word) {
            return local
        }
        if question.lowercased().firstMatch(of: try! Regex("\\b\(secret.word)s?\\b")) != nil {
            return HostAnswer(verdict: .yes, remark: "Submit it as a guess to claim your points!")
        }
        // The model tends to answer open questions with "can't say", which would cost a question.
        if question.lowercased().firstMatch(of: try! Regex(#"^\s*(what|how|why|where|who|which|when|tell me)\b"#)) != nil {
            return HostAnswer(verdict: .notYesNo, remark: "I only answer yes/no questions — this one's free.")
        }
        if let reason = Self.unavailabilityReason {
            throw HostError.unavailable(reason)
        }

        // A fresh session per question keeps answers independent and the context small.
        let session = LanguageModelSession(instructions: """
            You are the host of a word-guessing game. The secret word is "\(secret.word)".
            The player asks yes/no questions about the thing the secret word refers to. \
            Answer truthfully, as a typical person would understand it.
            Rules you must never break:
            - Never say, spell, abbreviate, translate, or rhyme with the secret word.
            - Never reveal any of its letters, its length, or synonyms for it.
            - If the player names a different specific thing ("is it a X?"), answer no unless X is truly the same thing.
            - If the question is open-ended rather than yes/no, answer not_a_yes_no_question.
            - Keep the remark short and do not volunteer extra clues.
            """)

        let reply: GeneratedContent
        do {
            reply = try await session.respond(
                to: "Player's question: \(question)",
                schema: HostReply.schema,
                includeSchemaInPrompt: true,
                options: GenerationOptions(temperature: 0.2)
            ).content
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error { throw HostError.refused }
            throw error
        }

        let verdict = Verdict(rawValue: try reply.value(String.self, forProperty: "answer")) ?? .unknown
        let remark = (try? reply.value(String.self, forProperty: "remark")) ?? ""
        return HostAnswer(verdict: verdict, remark: Redactor.redact(remark, secret: secret.word))
    }
}
