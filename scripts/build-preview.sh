#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product CharacterFolio
bin_path="$(swift build --show-bin-path)"
app_path="$PWD/Preview/Character Folio.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/CharacterFolio" "$app_path/Contents/MacOS/CharacterFolio"
cp scripts/Preview-Info.plist "$app_path/Contents/Info.plist"
cp -R "$bin_path/CharacterFolio_FolioCore.bundle" "$app_path/Contents/Resources/"
codesign --force --deep --sign - "$app_path"
printf 'Native preview ready: %s\n' "$app_path"
