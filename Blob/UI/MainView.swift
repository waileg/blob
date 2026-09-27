import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject var engine: SpeechEngine
    @StateObject private var model = MeetingModel()

    @State private var summary: MeetingSummary?
    @State private var useMistral = false
    @State private var mistralError: String?
    @State private var isSummarizing = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                TranscriptView(turns: engine.turns, interim: engine.interim)
                    .frame(minWidth: 320)
                SummaryPanel(
                    summary: summary,
                    isSummarizing: isSummarizing,
                    onSummarize: summarize,
                    onReset: reset
                )
                .frame(minWidth: 260)
            }
            Divider()
            controls
        }
        .frame(minWidth: 860, minHeight: 520)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            BlobatarView(
                name: "Blob",
                audioLevel: engine.audioLevel,
                isSpeaking: engine.state == .listening && engine.audioLevel > 0.12,
                size: 120
            )
            .padding(8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Blob")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(statusText)
                    .font(.callout)
                    .foregroundColor(.secondary)
                if engine.state == .listening {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                .frame(width: 5, height: 6 + engine.audioLevel * 28)
                                .foregroundColor(.accentColor)
                                .animation(.easeOut(duration: 0.12), value: engine.audioLevel)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var statusText: String {
        switch engine.state {
        case .idle: return "Listo para escuchar. Pulsa ⏺ para empezar."
        case .requesting: return "Pidiendo permiso de reconocimiento de voz…"
        case .listening: return "Escuchando… Habla normal."
        case .stopped: return "Pausado."
        case .denied: return "Sin permiso de micrófono/speech. Revísalo en Ajustes del sistema."
        }
    }

    private var controls: some View {
        HStack {
            Button {
                engine.state == .listening ? engine.stop() : engine.start()
            } label: {
                Label(engine.state == .listening ? "Parar" : "Escuchar", systemImage: engine.state == .listening ? "stop.fill" : "mic.fill")
            }
            .keyboardShortcut(.space, modifiers: .command)
            .disabled(engine.state == .requesting || engine.state == .denied)

            Button("Reiniciar transcripción") { reset() }
                .disabled(engine.turns.isEmpty && engine.interim.isEmpty)

            Spacer()

            Toggle("Usar Mistral AI para el resumen", isOn: $useMistral)
            if let mistralError {
                Text(mistralError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(2)
            }
            if isSummarizing { ProgressView().controlSize(.small) }
            Button("Resumir reunión") { summarize() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(engine.turns.isEmpty)
        }
        .padding()
    }

    private func summarize() {
        isSummarizing = true
        mistralError = nil
        let turns = engine.turns
        Task {
            defer { isSummarizing = false }
            if useMistral, let key = model.mistralKey, !key.isEmpty {
                let summarizer = MistralSummarizer(config: .init(
                    apiKey: key,
                    model: "mistral-small-latest",
                    endpoint: ConfigDefaults.endpoint,
                    timeout: 30
                ))
                do {
                    summary = try await summarizer.summarize(turns: turns)
                    return
                } catch {
                    mistralError = error.localizedDescription
                    // fall through to local
                }
            }
            summary = LocalSummarizer().summarize(turns: turns)
        }
    }

    private func reset() {
        engine.resetSession()
        summary = nil
        mistralError = nil
    }
}

/// Simple persisted settings holder.
final class MeetingModel: ObservableObject {
    @AppStorage("mistralKey") private var mistralKeyStorage: String = ""
    var mistralKey: String? { mistralKeyStorage.isEmpty ? nil : mistralKeyStorage }
}

enum ConfigDefaults {
    static let endpoint = URL(string: "https://api.mistral.ai/v1/chat/completions")!
}

struct SettingsView: View {
    @AppStorage("mistralKey") private var mistralKey: String = ""
    @AppStorage("localeID") private var localeID: String = ""
    @AppStorage("sensitivity") private var sensitivity: Double = 0.12

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes").font(.title2.bold())
            LabeledContent {
                SecureField("MISTRAL_API_KEY", text: $mistralKey)
                    .frame(width: 320)
            } label: {
                Text("Mistral API key (opcional)").font(.body)
            }
            LabeledContent {
                TextField("es-ES", text: $localeID)
                    .frame(width: 320)
            } label: {
                Text("Idioma (ej. es-ES, en-US)").font(.body)
            }
            LabeledContent {
                Slider(value: $sensitivity, in: 0.05...0.4)
                    .frame(width: 320)
            } label: {
                Text("Sensibilidad de voz").font(.body)
            }
            Text("Sin API key, Blob resume 100% en local.")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cerrar") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
