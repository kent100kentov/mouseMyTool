#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache dist/MagicTap.app/Contents/MacOS
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
xcrun clang -arch arm64 -mmacosx-version-min=13.0 -fobjc-arc -fblocks -O2 -Wall -Wextra -Wno-unused-parameter -c Sources/MTBridge.m -o build/MTBridge.o
xcrun swiftc -swift-version 5 -target arm64-apple-macosx13.0 -O -import-objc-header Sources/MTBridge.h Sources/TapSettings.swift Sources/TapRecognizer.swift Sources/CursorGuard.swift Sources/SettingsWindow.swift Sources/main.swift build/MTBridge.o -framework AppKit -framework ApplicationServices -framework IOKit -framework ServiceManagement -o dist/MagicTap.app/Contents/MacOS/MagicTap
cp Info.plist dist/MagicTap.app/Contents/Info.plist
codesign --force --sign "${SIGN_IDENTITY:--}" dist/MagicTap.app
printf 'Built: %s/dist/MagicTap.app\n' "$PWD"
