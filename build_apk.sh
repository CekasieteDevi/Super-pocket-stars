#!/usr/bin/env bash
# Arma el APK de Android y lo firma.
#
# Godot exporta y trata de firmar solo, pero elige apksigner de la version
# de build-tools que coincida con el targetSDK del template (36), y como esa
# no esta instalada cae a la 28.0.3, que falla EN SILENCIO: el APK sale sin
# firmar y el telefono lo rechaza al instalar. Por eso se firma aparte con
# una version moderna.
#
# Uso:  bash build_apk.sh
set -euo pipefail

GODOT="E:/IntelliJ/Super Pocket Stars/Godot_v4.7.1-stable_win64_console.exe"
PROYECTO="$(cd "$(dirname "$0")" && pwd)"
SALIDA="$PROYECTO/../build/SuperPocketStars.apk"
KEYSTORE="C:/Users/Administrator/AppData/Roaming/Godot/keystores/debug.keystore"
# La build-tools mas nueva de las instaladas.
APKSIGNER="$(ls -d D:/dev-tools/android-sdk/build-tools/*/apksigner.bat | sort -V | tail -1)"

mkdir -p "$(dirname "$SALIDA")"

echo "== exportando =="
"$GODOT" --path "$PROYECTO" --headless --export-debug Android "$SALIDA" \
  2>&1 | grep -viE "ADDING|^\[|scanning|loading|verifying|importing" | tail -5

echo "== firmando con $(basename "$(dirname "$APKSIGNER")") =="
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android \
  --ks-key-alias androiddebugkey --key-pass pass:android "$SALIDA"

echo "== verificando =="
"$APKSIGNER" verify "$SALIDA" && echo "FIRMA OK"
ls -la "$SALIDA"
