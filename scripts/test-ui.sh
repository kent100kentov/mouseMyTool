#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
xcrun swiftc -swift-version 5 Sources/TapSettings.swift Sources/SettingsWindow.swift Tests/SettingsWindow/main.swift -framework AppKit -o build/settings-window-tests
build/settings-window-tests
