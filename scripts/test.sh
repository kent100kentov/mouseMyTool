#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
xcrun swiftc -swift-version 5 Sources/TapSettings.swift Sources/TapRecognizer.swift Tests/main.swift -o build/recognizer-tests
build/recognizer-tests

xcrun swiftc -swift-version 5 Sources/CursorGuard.swift Tests/CursorGuard/main.swift -o build/cursor-tests
build/cursor-tests
