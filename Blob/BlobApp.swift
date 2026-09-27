import SwiftUI

@main
struct BlobApp: App {
    @StateObject private var engine = SpeechEngine()

    var body: some Scene {
        WindowGroup {
            MainView(engine: engine)
                .frame(minWidth: 860, minHeight: 520)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Blob") {
                Button("Escuchar / Parar") {
                    engine.state == .listening ? engine.stop() : engine.start()
                }
                .keyboardShortcut("space", modifiers: .command)
                Divider()
                Button("Reiniciar transcripción") {
                    engine.resetSession()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }
    }
}