import SwiftUI

struct TranscriptView: View {
    let turns: [TurnSegment]
    let interim: String

    var body: some View {
        List {
            Section {
                ForEach(turns) { turn in
                    TurnRow(turn: turn)
                }
            }
            if !interim.isEmpty && !turns.contains(where: { $0.text == interim }) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                    Text(interim).italic().foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset)
        .overlay {
            if turns.isEmpty && interim.isEmpty {
                Text("La transcripción aparecerá aquí.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Transcripción")
    }
}

private struct TurnRow: View {
    let turn: TurnSegment

    private var timeString: String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f.string(from: turn.start) ?? "0:00"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SpeakerAvatarView(name: "Hablante \(turn.speaker + 1)", size: 34)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Hablante \(turn.speaker + 1)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(timeString)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Text(turn.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}