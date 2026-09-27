import Foundation

struct Todo: Identifiable, Equatable {
    let id: UUID
    var text: String
    var speaker: Int
    /// nil when no due date is mentioned
    var due: Date?
    /// raw sentence it came from
    var source: String
}

struct MeetingSummary: Equatable {
    var title: String
    var highlights: [String]
    var todos: [Todo]
    var createdAt: Date
}

struct SpeakerStats: Identifiable, Equatable {
    let id: Int
    var name: String
    var wordCount: Int
    var talkTime: TimeInterval
    var turnCount: Int
}

// MARK: - Formatting

extension Todo {
    var displayText: String {
        if let due {
            "\(text) — \(due.formatted(date: .abbreviated, time: .omitted))"
        } else {
            text
        }
    }
}