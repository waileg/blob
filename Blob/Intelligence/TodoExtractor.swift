import Foundation
import NaturalLanguage

/// Extracts action items / commitments from transcript turns using NLTagger.
final class TodoExtractor {
    /// commitment verb lemmas (es / en)
    private static let commitVerbs: Set<String> = [
        // Spanish
        "hablar", "enviar", "mandar", "preparar", "revisar", "llamar", "escribir", "crear", "hacer",
        "terminar", "acabar", "enviaré", "mandaré", "haré", "revisaré", "prepararé", "crearé", "terminaré",
        "quedo", "quedamos", "encargo", "encargamos", "apunto", "apuntamos", "gestiono", "gestionamos",
        "encargado", "encargada", "pendiente",
        // English
        "send", "review", "prepare", "call", "write", "create", "make", "finish", "do",
        "share", "follow", "check", "draft", "schedule", "book", "update", "fix", "ship",
    ]

    /// explicit todo markers
    private static let markers: [String] = [
        "tengo que", "hay que", "tenemos que", "deberíamos", "debo", "me encargo", "te encargas",
        "action item", "to-do", "todo:", "pendiente", "no olvides", "acordamos", "quedamos en",
        "i'll", "i will", "we should", "we need to", "let's", "can you", "could you", "please",
        "necesitamos", "quedamos", "proponer",
    ]

    /// due-date keywords -> days from today
    private static let dueKeywords: [(String, Int)] = [
        ("hoy", 0), ("today", 0),
        ("mañana", 1), ("tomorrow", 1),
        ("pasado mañana", 2),
        ("esta semana", 7), ("this week", 7),
        ("la próxima semana", 14), ("próxima semana", 14), ("next week", 14),
        ("este mes", 30), ("this month", 30),
        ("lunes", 1), ("martes", 2), ("miércoles", 3), ("jueves", 4), ("viernes", 5),
        ("el viernes", 5),
    ]

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Returns todos extracted from the transcript.
    func extract(from turns: [TurnSegment]) -> [Todo] {
        var todos: [Todo] = []
        var seen = Set<String>()
        for turn in turns {
            for sentence in sentences(of: turn.text) {
                guard let todo = extractOne(sentence: sentence, speaker: turn.speaker) else { continue }
                let key = todo.text.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                todos.append(todo)
            }
        }
        return todos
    }

    func extractOne(sentence: String, speaker: Int) -> Todo? {
        let lower = sentence.lowercased()
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasMarker = Self.markers.contains { lower.contains($0) }
        guard hasMarker else { return nil }

        // NLTagger to confirm the sentence contains a verb in a "commitment" form,
        // and to grab lemmas for robustness across conjugations.
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = sentence
        var verbHit = false
        let range = sentence.startIndex..<sentence.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if let lemma = tag?.rawValue.lowercased() {
                if Self.commitVerbs.contains(lemma) { verbHit = true }
            }
            return true
        }
        // Weak sentences like "tenemos que ir" still count as commitments via marker.
        let strong = hasMarker && (verbHit || lower.contains("tengo que") || lower.contains("i'll"))

        guard strong else { return nil }

        // strip leading fillers
        var text = trimmed
        let fillers = ["bueno,", "ok,", "okey,", "vale,", "entonces,", "pues,", "well,", "so,", "um,", "eh,"]
        var stripped = true
        while stripped {
            stripped = false
            for f in fillers {
                if lower.hasPrefix(f) {
                    text = String(text.dropFirst(f.count)).trimmingCharacters(in: .whitespaces)
                    stripped = true
                    break
                }
            }
        }

        let due = dueDate(in: lower)

        return Todo(id: UUID(), text: text, speaker: speaker, due: due, source: trimmed)
    }

    private func sentences(of text: String) -> [String] {
        // simple and deterministic: split on ., !, ? and newlines
        text
            .split(whereSeparator: { c in c == "." || c == "!" || c == "?" || c.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func dueDate(in lower: String) -> Date? {
        for (kw, days) in Self.dueKeywords where lower.contains(kw) {
            if days == 0 {
                return calendar.startOfDay(for: Date())
            }
            if kw == "esta semana" || kw == "this week" {
                return calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))
            }
            return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date()))
        }
        return nil
        // NOTE: weekday handling is naive; LocalSummarizer can refine using dates in text.
    }
}
