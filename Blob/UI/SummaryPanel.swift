import SwiftUI

struct SummaryPanel: View {
    let summary: MeetingSummary?
    var isSummarizing: Bool
    var onSummarize: () -> Void
    var onReset: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let summary {
                    header(summary)
                    todosSection(summary.todos)
                    highlightsSection(summary.highlights)
                } else {
                    emptyState
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func header(_ s: MeetingSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.title)
                .font(.system(.title3, design: .rounded).bold())
            Text(s.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
        }
    }

    @ViewBuilder
    private func todosSection(_ todos: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("To-dos (\(todos.count))", systemImage: "checklist")
                .font(.headline)
            if todos.isEmpty {
                Text("Sin tareas detectadas.")
                    .foregroundColor(.secondary)
                    .font(.callout)
            } else {
                ForEach(todos) { todo in
                    HStack(alignment: .top, spacing: 10) {
                        SpeakerAvatarView(name: "Hablante \(todo.speaker + 1)", size: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(todo.displayText)
                                .font(.body)
                            if !todo.source.isEmpty {
                                Text("“\(todo.source)”")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if todo.due != nil {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func highlightsSection(_ highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Puntos clave", systemImage: "sparkles")
                .font(.headline)
            if highlights.isEmpty {
                Text("Sin puntos clave.")
                    .foregroundColor(.secondary)
                    .font(.callout)
            } else {
                ForEach(Array(highlights.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(h).font(.body)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            BlobatarView(name: "Blob", size: 90)
            Text("Aún no hay resumen.")
                .font(.headline)
            Text("Escucha una reunión y pulsa «Resumir reunión».\nBlob detecta tareas y puntos clave.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if isSummarizing { ProgressView() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}