// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "KeyFlowKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // 入力状態管理・レイアウト計算・設定モデル（UIKit非依存。Linuxでもテスト可能）
        .library(name: "KeyFlowCore", targets: ["KeyFlowCore"]),
        // かな漢字変換エンジン（AzooKeyKanaKanjiConverterのラッパー）
        .library(name: "KeyFlowEngine", targets: ["KeyFlowEngine"]),
        // キーボードの描画とタッチ処理（UIKit。アプリのプレビューと拡張機能で共有）
        .library(name: "KeyFlowKeyboardUI", targets: ["KeyFlowKeyboardUI"]),
    ],
    dependencies: [
        // 辞書の更新で変換精度が上がっているため、最新タグ(v0.11.2)ではなくmainの特定コミットに固定する
        // （eval/README.md の比較結果を参照）。
        // Zenzai（ニューラル変換）はキーボード拡張のメモリ上限とサイズを考慮して無効（traitを指定しない）。
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", revision: "04ce2ec3afe2bd6f92fcae1dc15a2357d332c27a"),
    ],
    targets: [
        .target(name: "KeyFlowCore"),
        .target(
            name: "KeyFlowEngine",
            dependencies: [
                "KeyFlowCore",
                .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "AzooKeyKanaKanjiConverter"),
            ]
        ),
        .target(name: "KeyFlowKeyboardUI", dependencies: ["KeyFlowCore"]),
        // 変換精度・速度の評価ツール（eval/README.md）。アプリには含まれない。
        .executableTarget(name: "KeyFlowEval", dependencies: ["KeyFlowEngine", "KeyFlowCore"]),
        .testTarget(name: "KeyFlowCoreTests", dependencies: ["KeyFlowCore"]),
        .testTarget(name: "KeyFlowEngineTests", dependencies: ["KeyFlowEngine", "KeyFlowCore"]),
    ],
    swiftLanguageModes: [.v5]
)
