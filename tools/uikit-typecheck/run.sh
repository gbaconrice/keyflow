#!/bin/bash
# UIKitの簡易スタブを使って、キーボードUIと拡張のコードをLinuxで型検査する。
# 本物のiOS SDKとはシグネチャが完全には一致しないため、通っても最終確認はCI（macOS）で行う。
#
# 使い方: tools/uikit-typecheck/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$HERE/.work"
mkdir -p "$WORK/Sources"
cd "$WORK"

rm -rf Sources/*
mkdir -p Sources/UIKit
cp "$HERE/Stub/UIKit.swift" Sources/UIKit/
ln -s "$ROOT/Packages/KeyFlowKit/Sources/KeyFlowCore" Sources/KeyFlowCore
ln -s "$ROOT/Packages/KeyFlowKit/Sources/KeyFlowEngine" Sources/KeyFlowEngine
# Linuxでは@objcと#selectorを扱えないので、取り除いた写しを作る
python3 - "$ROOT" <<'PY'
import os, re, sys
root = sys.argv[1]
for target, src in {"KeyFlowKeyboardUI": "Packages/KeyFlowKit/Sources/KeyFlowKeyboardUI", "KeyboardExt": "Keyboard"}.items():
    dst = os.path.join("Sources", target)
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(os.path.join(root, src)):
        if f.endswith(".swift"):
            s = open(os.path.join(root, src, f)).read().replace("@objc ", "")
            s = re.sub(r"#selector\(([^()]*(?:\([^()]*\))?)\)", r'Selector("\1")', s)
            open(os.path.join(dst, f), "w").write(s)
PY

REV="$(grep -o 'revision: "[0-9a-f]*"' "$ROOT/Packages/KeyFlowKit/Package.swift" | cut -d'"' -f2)"
cat > Package.swift <<SWIFT
// swift-tools-version: 6.1
import PackageDescription
let package = Package(
    name: "uikit-typecheck",
    dependencies: [.package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", revision: "$REV")],
    targets: [
        .target(name: "UIKit"),
        .target(name: "KeyFlowCore"),
        .target(name: "KeyFlowEngine", dependencies: ["KeyFlowCore", .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "AzooKeyKanaKanjiConverter")]),
        .target(name: "KeyFlowKeyboardUI", dependencies: ["KeyFlowCore", "UIKit"]),
        .target(name: "KeyboardExt", dependencies: ["KeyFlowCore", "KeyFlowEngine", "KeyFlowKeyboardUI", "UIKit"]),
    ],
    swiftLanguageModes: [.v5]
)
SWIFT
swift build --target KeyboardExt 2>&1 | grep -E "error:|warning: .*(KeyFlowKeyboardUI|KeyboardExt)/" | grep -v "deprecated" || true
swift build --target KeyboardExt > /dev/null 2>&1 && echo "typecheck: OK" || { echo "typecheck: FAILED"; exit 1; }
