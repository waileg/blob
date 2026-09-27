import Foundation
import NaturalLanguage

/// Offline meeting summarizer: key sentences + speaker stats + todos.
final class LocalSummarizer {
    private let extractor: TodoExtractor

    init(extractor: TodoExtractor = TodoExtractor()) {
        self.extractor = extractor
    }

    func summarize(turns: [TurnSegment], createdAt: Date = Date()) -> MeetingSummary {
        guard !turns.isEmpty else {
            return MeetingSummary(title: "Sin actividad", highlights: [], todos: [], createdAt: createdAt)
        }

        let todos = extractor.extract(from: turns)
        _ = speakerStats(turns: turns)

        var title = "Reunión"
        if let first = turns.first, first.text.count > 3 {
            let words = first.text.prefix(40)
            title = String(words)
            if first.text.count > 40 { title += "…" }
        }

        return MeetingSummary(
            title: title,
            highlights: highlights(turns: turns),
            todos: todos,
            createdAt: createdAt
        )
    }

    // MARK: Highlights

    private func highlights(turns: [TurnSegment]) -> [String] {
        var scored: [(String, Double)] = []
        for turn in turns {
            for sentence in splitSentences(turn.text) {
                let lower = sentence.lowercased()
                var score = 0.0
                if lower.contains("tengo que") || lower.contains("i'll") || lower.contains("hay que") || lower.contains("acordamos") || lower.contains("quedamos") { score += 2 }
                if lower.contains("decidimos") || lower.contains("conclusión") || lower.contains("decided") || lower.contains("conclusion") { score += 1.5 }
                let wc = sentence.split(whereSeparator: { $0.isWhitespace }).count
                if (6...25).contains(wc) { score += 1 }
                if wc > 35 { score -= 1 }
                if score > 1.5 {
                    scored.append((sentence, score))
                }
            }
        }
        let top = Set(scored.sorted { $0.1 > $1.1 }.prefix(5).map(\.0))
        return scored.filter { top.contains($0.0) }.map(\.0)
    }

    private func splitSentences(_ text: String) -> [String] {
        text
            .split(whereSeparator: { c in c == "." || c == "!" || c == "?" || c.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: Stats

    func speakerStats(turns: [TurnSegment]) -> [SpeakerStats] {
        var map: [Int: (words: Int, time: TimeInterval, count: Int)] = [:]
        for t in turns {
            let words = t.text.split(whereSeparator: { $0.isWhitespace }).count
            var e = map[t.speaker] ?? (0, 0, 0)
            e.words += words
            e.time += max(t.end - t.start, 0.5)
            e.count += 1
            map[t.speaker] = e
        }
        return map
            .map { SpeakerStats(id: $0.key, name: "Hablante \($0.key + 1)", wordCount: $0.value.words, talkTime: $0.value.time, turnCount: $0.value.count) }
            .sorted { $0.wordCount > $1.wordCount }
    }
}
