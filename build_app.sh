#!/bin/bash
# Build Blob.app WITHOUT Xcode — only needs Command Line Tools (swift build).
# Usage: bash build_app.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Blob"
BUNDLE_ID="ai.blob.app"
VERSION="0.1.0"

echo "==> Compilando (esto puede tardar un poco la primera vez)..."
swift build -c release

BIN=".build/release/${APP_NAME}"
[ -f "$BIN" ] || { echo "ERROR: no se generó el binario"; exit 1; }

APP="${APP_NAME}.app"
CONTENTS="${APP}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

echo "==> Empaquetando ${APP}..."
cp "$BIN" "$MACOS/${APP_NAME}"

# Icon (regenerable con gen_icon.py; si no existe, la app usa icono genérico)
if [ ! -f "Blob/Assets.xcassets/AppIcon.appiconset/AppIcon.png" ]; then
  echo "==> Generando icono..."
  python3 Scripts/gen_icon.py "Blob/Assets.xcassets/AppIcon.appiconset/AppIcon.png" 2>/dev/null || \
    echo "   (sin python3: icono genérico)"
fi
[ -f "Blob/Assets.xcassets/AppIcon.appiconset/AppIcon.png" ] && \
  cp "Blob/Assets.xcassets/AppIcon.appiconset/AppIcon.png" "${RESOURCES}/AppIcon.png"

cat > "${CONTENTS}/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Blob</string>
	<key>CFBundleDisplayName</key>
	<string>Blob</string>
	<key>CFBundleIdentifier</key>
	<string>ai.blob.app</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleExecutable</key>
	<string>Blob</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<false/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Blob escucha el micrófono para transcribir y resumir tus reuniones en tu Mac.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Blob usa el reconocimiento de voz de Apple (en local) para transcribir lo que se dice en tus reuniones.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

echo "==> Firmando (ad-hoc, para que macOS la deje correr)..."
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "   (codesign no disponible: puede pedir clic derecho->Abrir)"

echo ""
echo "✅ Listo: $(pwd)/${APP}"
echo ""
echo "Para instalarla como app más:"
echo "  cp -R ${APP} /Applications/"
echo "Y ábrela desde Finder/Launchpad (la 1ª vez: clic derecho -> Abrir)."
