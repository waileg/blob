import AVFoundation
import Speech
import Foundation

/// Live dictation engine: AVAudioEngine input tap -> SFSpeechRecognizer,
/// plus live level metering and turn segmentation.
final class SpeechEngine: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    enum State: Equatable {
        case idle
        case requesting
        case listening
        case stopped
        case denied
    }

    @Published var state: State = .idle
    @Published var transcript: String = ""
    @Published var audioLevel: Double = 0
    @Published var turns: [TurnSegment] = []
    @Published var interim: String = ""

    private var audioEngine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private let meter = AudioLevelMeter()
    private let segmenter = SpeakerSegmenter()
    private var chunkStart: TimeInterval?
    private var chunkEnergy: [Double] = []
    private var chunkWords = 0

    var locale: Locale

    init(locale: Locale? = nil) {
        if let locale {
            self.locale = locale
        } else if let id = UserDefaults.standard.string(forKey: "localeID"), !id.isEmpty {
            self.locale = Locale(identifier: id)
        } else {
            self.locale = .current
        }
        super.init()
    }

    // MARK: Control

    func start() {
        guard state != .listening, state != .requesting else { return }
        state = .requesting
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.beginListening()
                default:
                    self?.state = .denied
                }
            }
        }
    }

    func stop() {
        guard state == .listening else { return }
        finishChunk()
        task?.finish()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        state = .stopped
        interim = ""
    }

    func resetSession() {
        segmenter.reset()
        transcript = ""
        turns = []
    }

    // MARK: Engine wiring

    private func beginListening() {
        // Note: AVAudioSession is iOS-only; macOS grants mic access via the
        // NSMicrophoneUsageDescription prompt, no session setup needed.
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer() else {
            state = .denied
            return
        }
        recognizer.delegate = self

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let level = self.meter.process(buffer: buffer)
            DispatchQueue.main.async {
                self.audioLevel = level
            }
            self.request?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            state = .denied
            return
        }

        self.recognizer = recognizer
        self.request = request
        self.audioEngine = engine
        state = .listening

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result {
                    self.handle(result: result)
                }
                if error != nil || result?.isFinal == true {
                    if self.state == .listening {
                        self.restartAfterInterruption()
                    } else {
                        self.state = .stopped
                    }
                }
            }
        }
    }

    private func restartAfterInterruption() {
        task?.finish()
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        guard let request, let recognizer else { return }
        chunkStart = nil
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result { self.handle(result: result) }
                if error != nil || result?.isFinal == true {
                    if self.state == .listening { self.restartAfterInterruption() }
                }
            }
        }
    }

    // MARK: Result handling

    private func handle(result: SFSpeechRecognitionResult) {
        let text = result.bestTranscription.formattedString

        interim = text
        if chunkStart == nil { chunkStart = Date().timeIntervalSinceReferenceDate }
        chunkWords = wordCount(of: text)
        chunkEnergy.append(meter.level)

        // When finalized text ends with sentence punctuation, close the chunk.
        if result.isFinal || text.hasSuffix(".") || text.hasSuffix("?") || text.hasSuffix("!") {
            finishChunk(text: text)
        }
    }

    private func finishChunk(text: String? = nil) {
        let body = text ?? interim
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let start = chunkStart else { return }
        let end = Date().timeIntervalSinceReferenceDate
        let duration = max(end - start, 0.5)
        let energy = chunkEnergy.isEmpty ? meter.level : chunkEnergy.reduce(0, +) / Double(chunkEnergy.count)
        let pace = Double(chunkWords) / duration
        _ = segmenter.addChunk(start: start, end: end, text: trimmed, energy: energy, pace: pace)
        turns = segmenter.turns
        transcript = turns.map { t in
            "\(t.speaker): \(t.text)"
        }.joined(separator: "\n")
        chunkStart = nil
        chunkEnergy.removeAll()
        chunkWords = 0
        interim = ""
    }

    private func wordCount(of text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
