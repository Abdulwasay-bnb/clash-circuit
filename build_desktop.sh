#!/usr/bin/env bash
# Build the Windows and Linux versions (single self-contained executables) and zip them.
# Output: build/ClashCircuit-windows.zip, build/ClashCircuit-linux.zip
# Needs the Godot 4.3 export templates (windows_*_x86_64.exe, linux_*.x86_64).
set -euo pipefail
cd "$(dirname "$0")"
GD="$HOME/Applications/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p build/windows build/linux && touch build/.gdignore
"$GD" --headless --path . --import >/dev/null 2>&1 || true
"$GD" --headless --path . --export-release "Windows Desktop" build/windows/ClashCircuit.exe
"$GD" --headless --path . --export-release "Linux" build/linux/ClashCircuit.x86_64
(cd build/windows && rm -f ../ClashCircuit-windows.zip && zip -q ../ClashCircuit-windows.zip ClashCircuit.exe)
(cd build/linux && chmod +x ClashCircuit.x86_64 && rm -f ../ClashCircuit-linux.zip && zip -q ../ClashCircuit-linux.zip ClashCircuit.x86_64)
ls -la build/*.zip
