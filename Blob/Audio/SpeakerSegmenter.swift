import Foundation

/// Rule-based speaker turn segmentation.
///
/// Pure logic, no Apple frameworks — so it can be unit-tested and was verified
/// against a Python port of itself. On-device we also have voice metrics
/// (energy + pace) that refine the same decisions.
struct TurnSegment: Identifiable, Equatable, Hashable {
    let id: Int
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    /// 0...1 mean energy while speaking
    var energy: Double
    /// words per second
    var pace: Double
    /// tentatively assigned speaker label
    var speaker: Int
}

struct SpeakerProfile: Identifiable, Equatable {
    let id: Int
    var meanEnergy: Double
    var meanPace: Double
    var turnCount: Int

    func distance(energy: Double, pace: Double) -> Double {
        let e = abs(energy - meanEnergy) / 0.25
        let p = abs(pace - meanPace) / 1.5
        return e + p
    }
}

/// Splits a live stream of (timestamp, level) samples and finalized text
/// chunks into speaker turns.
final class SpeakerSegmenter {
    struct RawChunk {
        let start: TimeInterval
        let end: TimeInterval
        let text: String
        let energy: Double
        let pace: Double
    }

    private(set) var turns: [TurnSegment] = []
    private var profiles: [SpeakerProfile] = []
    private var nextTurnID = 0
    private var nextSpeakerProbe = 0

    /// gap (seconds) that closes a turn
    var turnGap: Double = 1.4
    /// distance threshold to spawn a new speaker profile
    var newSpeakerDistance: Double = 1.1

    /// Feed finalized recognition chunks in order.
    func addChunk(start: TimeInterval, end: TimeInterval, text: String, energy: Double, pace: Double) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var mergedIntoPrevious = false
        var speakerID: Int?

        if var last = turns.last, end - last.end < turnGap {
            let dists = profiles.map { $0.distance(energy: energy, pace: pace) }
            if let minDist = dists.min(), let idx = dists.firstIndex(of: minDist), minDist < newSpeakerDistance {
                speakerID = last.speaker
                mergedIntoPrevious = true
                last.text += " " + trimmed
                last.end = max(last.end, end)
                last.energy = (last.energy + energy) / 2
                last.pace = (last.pace + pace) / 2
                turns[turns.count - 1] = last
                updateProfile(profiles[idx], id: profiles[idx].id, energy: energy, pace: pace)
            }
        }

        if !mergedIntoPrevious {
            let dists = profiles.map { $0.distance(energy: energy, pace: pace) }
            if let minDist = dists.min(), let idx = dists.firstIndex(of: minDist), minDist < newSpeakerDistance {
                speakerID = profiles[idx].id
                updateProfile(profiles[idx], id: profiles[idx].id, energy: energy, pace: pace)
            } else {
                let newID = nextSpeakerProbe
                nextSpeakerProbe += 1
                profiles.append(SpeakerProfile(id: newID, meanEnergy: energy, meanPace: pace, turnCount: 1))
                speakerID = newID
            }
            let t = TurnSegment(id: nextTurnID, text: trimmed, start: start, end: end, energy: energy, pace: pace, speaker: speakerID!)
            turns.append(t)
            nextTurnID += 1
        }
        return speakerID
    }

    private func updateProfile(_ profile: SpeakerProfile, id: Int, energy: Double, pace: Double) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        let p = profiles[i]
        let n = Double(p.turnCount + 1)
        profiles[i].meanEnergy = (p.meanEnergy * Double(p.turnCount) + energy) / n
        profiles[i].meanPace = (p.meanPace * Double(p.turnCount) + pace) / n
        profiles[i].turnCount += 1
    }

    func reset() {
        turns = []
        profiles = []
        nextTurnID = 0
        nextSpeakerProbe = 0
    }
}