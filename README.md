# Blob 🫧

Un ayudante para Mac que escucha lo que pasa, entiende **quién habla**, **cómo lo dice** y resume la reunión con to-dos.

- **Todo en local** con fundamentales de Apple: `Speech`, `NaturalLanguage`, `AVFoundation`.
- **Conector opcional de Mistral AI**: si configuras tu API key, Blob envía la transcripción a Mistral para un resumen más rico; si no, hace un resumen 100% local (offline).
- **Blobatar**: la cara de Blob se genera de forma determinista desde un string (idea de [blobatar.dev](https://blobatar.dev/)) — mismo nombre, misma carita. La identidad de cada hablante detectado también recibe su propio blobatar.

## Estado

Funcionalidad básica operativa (MVP):

1. **Escucha** el micrófono del Mac con `SFSpeechRecognizer` + `AVAudioEngine`, en vivo.
2. **Segmentación de hablante**: usa pausas + energía + ritmo del habla para separar turnos y asignar un "Hablante 1/2/3" tentativo a cada turno.
3. **Transcripción en vivo** con marcas de tiempo y hablante.
4. **Detección de to-dos**: analiza cada turno con `NLTagger` buscando frases de compromiso ("tengo que…", "lo hago mañana", "I'll…", "action item") y extrae una tarea con plazo si aparece.
5. **Resumen**: local (frases clave + to-dos) o vía Mistral AI si hay key configurada.
6. **Blob vivo**: blobatar que reacciona — respira en reposo, se agranda cuando detecta voz y "mira" el nivel de audio en tiempo real.

## Build (Mac)

Requiere Xcode 15+ y macOS 13+.

```bash
open Blob.xcodeproj        # y Cmd+R
```

O vía CLI:

```bash
xcodebuild -project Blob.xcodeproj -scheme Blob -configuration Debug build
```

La primera vez macOS pedirá permiso de **micrófono** y **reconocimiento de voz** (Speech). Acepta ambos.

### Mistral AI (opcional)

En la app: Blob → Ajustes → pega tu `MISTRAL_API_KEY`. Sin key, todo funciona en local.

## Estructura

```
Blob/
├── Blob.xcodeproj/project.pbxproj      # proyecto Xcode generado
├── Blob/
│   ├── BlobApp.swift                   # @main, menú
│   ├── Info.plist                      # NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
│   ├── Assets.xcassets/                # AppIcon, colores
│   ├── Blobatar/
│   │   ├── Blobatar.swift              # generador determinista (hash → forma + color)
│   │   ├── BlobatarView.swift          # Canvas SwiftUI + animación (respiración, voz, mirada)
│   │   └── SilhouetteShapes.swift      # 10 siluetas como Path
│   ├── Audio/
│   │   ├── SpeechEngine.swift          # SFSpeechRecognizer + AVAudioEngine, buffer live
│   │   ├── SpeakerSegmenter.swift      # separación de turnos: pausas + energía + ritmo
│   │   └── AudioLevelMeter.swift       # RMS / dBFS en vivo
│   ├── Intelligence/
│   │   ├── TodoExtractor.swift         # NLTagger: verbos de compromiso + plazos
│   │   ├── LocalSummarizer.swift       # resumen offline (TF simplificado + to-dos)
│   │   ├── MistralSummarizer.swift     # conector opcional a Mistral API
│   │   └── Summary.swift               # modelo (SummaryItem, Todo)
│   └── UI/
│       ├── MainView.swift             # ventana principal
│       ├── TranscriptView.swift        # lista de turnos
│       ├── SummaryPanel.swift          # resumen + to-dos
│       └── SettingsView.swift          # idioma, Mistral key, sensibilidad
└── Scripts/
    └── test_logic.py                   # verificación de la lógica determinista
```

## Notas

- El proyecto se verificó con lógica pura (ver `Scripts/test_logic.py`): determinismo del blobatar, segmentación de hablante y extracción de to-dos, todo portado 1:1 a Python. Compilar y ejecutar es un paso en Mac.
- El blobatar es una implementación original en Swift inspirada en el concepto de blobatar.dev (mismo string → mismo avatar) y no usa código de blobatar.