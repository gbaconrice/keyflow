# 変換評価

## ファイル

- `corpus.tsv`: 評価用の文。`読み<TAB>正解（|で複数）<TAB>分類`。分類は general / casual / proper / game / mixed / business。
- `compare_cli.py`: AzooKeyKanaKanjiConverter付属のCLI（anco）を使い、エンジン・辞書のバージョンどうしを比べる。

## KeyFlowのエンジンで評価する

```bash
cd Packages/KeyFlowKit
swift build -c release --product KeyFlowEval
.build/release/KeyFlowEval ../../eval/corpus.tsv
```

キーボードと同じ`AzooKeyEngine`を通し、1文字ずつ変換して時間を測る。結果は docs/EVALUATION.md に転記する。

## エンジンのバージョンを比べる

```bash
git clone https://github.com/azooKey/AzooKeyKanaKanjiConverter A && (cd A && git checkout <commit> && git submodule update --init && swift build -c release --product CliTool)
git clone https://github.com/azooKey/AzooKeyKanaKanjiConverter B && (cd B && git checkout <commit> && git submodule update --init && swift build -c release --product CliTool)
python3 eval/compare_cli.py eval/corpus.tsv "A=A/.build/release/CliTool" "B=B/.build/release/CliTool"
```

辞書はサブモジュールなので、バージョンごとに別のディレクトリでビルドすること（同じディレクトリで切り替えると、古いバイナリが新しい辞書を読んでしまう）。

エンジンを更新したら、`Packages/KeyFlowKit/Sources/KeyFlowEngine/PartOfSpeech.swift`の品詞IDが新しいエンジンの`DicdataStore._getPredictionUsable`と一致しているかも確かめる（品詞IDの表が変わると、変換の補正が誤って働く）。

### 2026-10-21 の比較

| | 1位 | 3位以内 | 10位以内 |
|---|---|---|---|
| v0.11.2 | 81% | 94% | 98% |
| main@04ce2ec | 85% | 94% | 98% |

mainの方が辞書が新しく、「今日は」「3時」などが改善している。KeyFlowは main@04ce2ec を使う。

## 文を追加するとき

- 読みはフリックで入力できるひらがな・数字・記号にする（カタカナは不可）。
- 正解の表記が複数ありうるときは `|` で並べる。好みが分かれる表記を1つに決めつけない。
- 分類ごとの件数の偏りに注意する。
