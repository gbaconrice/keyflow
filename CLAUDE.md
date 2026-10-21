# KeyFlow 開発メモ（AIアシスタント・開発者向け）

作業を始める前に docs/PROGRESS.md を読み、終わったら更新する。

## 目的と優先順位

iPhone用の日本語キーボード（Keyboard Extension）。優先順位:
1. 日本語入力の快適さ 2. 変換精度 3. 応答と安定性 4. サイズ・配置 5. 編集操作 6. iOSとの互換性 7. UI 8. 追加機能

禁止: 広告、課金、外部送信、ネットワークを使うAI機能。フルアクセスなしで動くこと。

## 環境

- 利用者はWindows + iPhone、Macなし、無料のApple Account。
- iOSのビルドはGitHub Actions（macOS）で行う。クラウドのLinux環境ではiOS SDKを使えない。
- Apple Accountのパスワードや署名用の秘密情報をリポジトリ・クラウドに置かない。
- 実機で確認していないことを「確認済み」と書かない。

## よく使うコマンド

```bash
# Linuxでのテスト（Swift 6.1以上）
cd Packages/KeyFlowKit && swift test

# 変換精度・応答時間の評価
cd Packages/KeyFlowKit && swift build -c release --product KeyFlowEval && .build/release/KeyFlowEval ../../eval/corpus.tsv

# Xcodeプロジェクトの生成（macOS）
xcodegen generate
```

Linuxで UIKit のコードを型検査するには `tools/uikit-typecheck/run.sh` を使う。スタブは本物のSDKと完全には一致しないので、最終確認はCIで行う。

## 構成の要点

- `KeyFlowCore` はUIKitに依存させない（Linuxでテストするため）。入力のロジックはここに置く。
- 入力欄の操作は `TextDocument` 経由。テストは `SimulatedTextField` で行う。
- 変換は `ConversionQueue`（直列キュー）経由でのみ呼ぶ。`KanaKanjiConverter` はスレッドセーフではない。
- 新しい入力操作を足したら `InputControllerTests` にテストを足す。
- UIの文言は短く自然な日本語にする（human-ja スキルの方針）。

## 変換エンジンの更新

`Packages/KeyFlowKit/Package.swift` で AzooKeyKanaKanjiConverter をコミット固定している。
上げるときは eval/README.md の手順で新旧を比べ、精度が下がらないことを確かめる。
