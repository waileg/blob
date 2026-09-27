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

## Ejecutar SIN Xcode (app normal .app)

Solo necesitas las **Command Line Tools** (gratuitas, ~1.5 GB, sin Xcode):

```bash
xcode-select --install   # si no las tienes ya
```

Descarga o clona el repo, y dentro de la carpeta:

```bash
bash build_app.sh
```

El script compila con `swift build`, empaqueta **Blob.app**, genera el icono y la firma. Luego:

```bash
cp -R Blob.app /Applications/   # instalar como app más
```

Ábrela desde Finder o Launchpad. **La primera vez**: clic derecho sobre Blob → **Abrir** → confirmar (macOS es desconfiado con apps sin firma de desarrollador).

Pedirá permiso de **micrófono** y **reconocimiento de voz** → acepta ambos.

## Ejecutar CON Xcode (para desarrollo)

Requiere Xcode 15+ y macOS 13+.

```bash
open Blob.xcodeproj   # y Cmd+R
```

## Mistral AI (opcional)

En la app: Blob → Ajustes → pega tu `MISTRAL_API_KEY`. Sin key, todo funciona en local.

## Estructura

```
Blob/
├── Package.swift                  # compilación sin Xcode (swift build)
├── build_app.sh                    # empaqueta Blob.app (sin Xcode)
├── Blob.xcodeproj/project.pbxproj  # proyecto Xcode (alternativa)
├── Blob/
│   ├── BlobApp.swift               # @main, menú
│   ├── Info.plist                  # permisos mic + speech
│   ├── Blobatar/                   # generador determinista + vista viva
│   ├── Audio/                      # SpeechEngine, SpeakerSegmenter, AudioLevelMeter
│   ├── Intelligence/              # TodoExtractor, LocalSummarizer, MistralSummarizer
│   └── UI/                         # MainView, TranscriptView, SummaryPanel
└── Scripts/
    ├── test_logic.py              # tests de la lógica (10, todos pasan)
    ├── gen_icon.py                 # generador del icono
    └── gen_project.py              # regenerador del .xcodeproj
```

## Notas

- Lógica verificada con port Python (`Scripts/test_logic.py`): determinismo del blobatar, segmentación de hablante y extracción de to-dos. 10/10 tests OK.
- El blobatar es una implementación original en Swift inspirada en el concepto de blobatar.dev (mismo string → mismo avatar) y no usa código de blobatar.
