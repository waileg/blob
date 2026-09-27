import Foundation

/// Optional connector to the Mistral API for richer summaries.
/// If no key is configured (or the request fails) the caller falls back to LocalSummarizer.
final class MistralSummarizer {
    struct Config {
        var apiKey: String
        var model: String
        var endpoint: URL
        var timeout: TimeInterval

        static let standard = Config(
            apiKey: "",
            model: "mistral-small-latest",
            endpoint: URL(string: "https://api.mistral.ai/v1/chat/completions")!,
            timeout: 30
        )
    }

    enum MistralError: LocalizedError {
        case noKey
        case http(Int, String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .noKey: return "No hay API key de Mistral configurada"
            case .http(let code, let body): return "Mistral HTTP \(code): \(body.prefix(200))"
            case .decoding: return "Respuesta de Mistral no válida"
            }
        }
    }

    private let config: Config

    init(config: Config) {
        self.config = config
    }

    var isConfigured: Bool { !config.apiKey.isEmpty }

    func summarize(turns: [TurnSegment]) async throws -> MeetingSummary {
        guard isConfigured else { throw MistralError.noKey }

        let transcript = turns
            .map { "Hablante \($0.speaker + 1): \($0.text)" }
            .joined(separator: "\n")

        let prompt = """
        Eres Blob, un ayudante que resume reuniones. Recibes la transcripción de una reunión \
        con hablantes numerados. Devuelve SOLO JSON válido con este formato exacto:
        {"title": "...", "highlights": ["..."], "todos": [{"text": "...", "speaker": 1, "due": null}]}
        - "title": título corto de la reunión.
        - "highlights": 3 a 5 puntos clave, en orden cronológico.
        - "todos": cada compromiso o tarea mencionada. "due" es null o una fecha ISO (YYYY-MM-DD) si se menciona plazo.
        - Responde en el idioma de la transcripción.

        Transcripción:
        \(transcript)
        """

        struct Msg: Codable { let role: String; let content: String }
        struct Body: Codable {
            let model: String
            let messages: [Msg]
            let temperature: Double
        }
        struct Resp: Codable {
            struct Choice: Codable { let message: Msg }
            let choices: [Choice]
        }

        let body = try JSONEncoder().encode(Body(model: config.model, messages: [.init(role: "user", content: prompt)], temperature: 0.2))

        var req = URLRequest(url: config.endpoint, timeoutInterval: config.timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw MistralError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            throw MistralError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let content = resp.choices.first?.message.content else { throw MistralError.decoding }
        return try parse(content: content, fallbackTurns: turns)
    }

    private func parse(content: String, fallbackTurns: [TurnSegment]) throws -> MeetingSummary {
        // strip code fences if present
        var json = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            json = json
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        struct ParsedTodo: Codable {
            let text: String
            let speaker: Int
            let due: String?
        }
        struct Parsed: Codable {
            let title: String
            let highlights: [String]
            let todos: [ParsedTodo]
        }

        guard let data = json.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Parsed.self, from: data) else {
            throw MistralError.decoding
        }

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        let todos = parsed.todos.map { t -> Todo in
            let due = t.due.flatMap { df.date(from: $0) }
            return Todo(id: UUID(), text: t.text, speaker: max(0, t.speaker - 1), due: due, source: "")
        }
        return MeetingSummary(title: parsed.title, highlights: parsed.highlights, todos: todos, createdAt: Date())
    }
}
