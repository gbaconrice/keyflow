# KeyFlow

iPhone用の日本語キーボードです。フリック入力の快適さと変換精度、入力の安定性を最優先にしています。
広告・課金・外部への送信はありません。フルアクセスなしで使えます。

- かな漢字変換: [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)（端末内で完結）
- 個人利用のため、無料のApple Accountで署名してインストールする前提です（App Storeでは配布しません）

> **状態**: 実装は一通りそろっていますが、iOS向けのビルドと実機での動作はまだ確認していません。詳しくは [docs/PROGRESS.md](docs/PROGRESS.md)。

## 主な機能

- 12キーのフリック入力（トグル入力のオン／オフ、判定距離の調整、フリック先の表示）
- 「小゛゜」キーのタップで巡回、フリックで濁点・小文字・半濁点を直接指定
- 変換・予測変換・確定後の次の語の予測、文節ごとの確定、学習、ユーザー辞書
- 確定直後の「取消」で読みに戻して選び直す。テキストを選択すると変換し直す候補を出す
- ◀▶キーと空白キーのドラッグでカーソル移動。入力中は入力中の文字列の中で動き、変換する範囲を変えられる
- キーボードの高さ（縦・横）、キーの間隔、余白、文字の大きさ、片手モード
- 設定画面の下に実物と同じキーボードのプレビューを表示し、打ちながら調整できる
- キーボード上の調整パネル（高さ・片手・判定距離など）
- ダークモード、横画面、英字（QWERTY／12キー）、数字・記号のフリック、記号・顔文字の一覧

## ドキュメント

- [インストール手順（Windows）](docs/INSTALL.md)
- [設計](docs/DESIGN.md)
- [進捗・実機確認項目](docs/PROGRESS.md)
- [評価基準と結果](docs/EVALUATION.md)
- [iOSの制約の調査](docs/research/ios-keyboard-constraints.md)

## ビルド

iOS向けのビルドにはmacOSとXcodeが必要です。手元にMacがない前提で、GitHub Actionsでビルドします（`.github/workflows/build.yml`）。
成果物 `KeyFlow-ipa` を署名ツールで署名してインストールします。

共有コード（入力状態管理・変換エンジン）はLinuxでもテストできます。

```bash
cd Packages/KeyFlowKit
swift test
```

Macがある場合:

```bash
brew install xcodegen
xcodegen generate
open KeyFlow.xcodeproj
```

## ライセンス

依存ライブラリのライセンスはアプリ内の「ライセンス」画面に表示しています。
- AzooKeyKanaKanjiConverter: MIT License
- azooKey_dictionary_storage: Apache License 2.0
- swift-algorithms / swift-collections / swift-numerics / swift-tokenizers: Apache License 2.0
- Jinja: MIT License
