# iOS カスタムキーボード（Keyboard Extension）制約調査

- 調査日: 2026-10-21
- 対象: iOS 18 / iOS 26（個人利用の日本語キーボード、`UIInputViewController` ベース）
- 補足: 調査時点では iOS 27 もリリース済み。iOS 27 固有の情報は参考として明記した場合のみ扱う。
- 出典ラベル:
  - **【公式】** developer.apple.com / support.apple.com の記述
  - **【公式・旧】** Apple のアーカイブ文書（App Extension Programming Guide 等、iOS 8 期の Retired Document）。現行ドキュメントと食い違う場合は現行を優先
  - **【非公式】** Apple Developer Forums のユーザー投稿（Apple 社員の回答は別記）、GitHub、ブログ、第三者 SDK のドキュメント
  - **【未確認】** 一次情報で確認できなかったもの。理由を併記
- API 名は Swift 表記（Objective-C 名は必要な場合のみ併記）

---

## 1. カスタムキーボード全般の制約

### 不可能（システムが強制）
| 制約 | 内容 | 出典 |
|---|---|---|
| セキュアテキスト欄 | `isSecureTextEntry == true` の欄（パスワード欄）では、システムキーボードに一時的に差し替わる。非セキュア欄に戻ると自動で復帰 | 【公式】[B] [E] |
| 電話番号パッド | `UIKeyboardType.phonePad` / `.namePhonePad` の欄ではシステムキーボードが出る | 【公式】[B] [E] |
| アプリ側の拒否 | ホストアプリが `application(_:shouldAllowExtensionPointIdentifier:)` で `UIApplication.ExtensionPointIdentifier.keyboard`（`com.apple.keyboard-service`）に `false` を返すと、そのアプリではカスタムキーボードが表示されない | 【公式】[B] [I] |
| テキスト選択・編集メニュー | キーボードは自分の primary view の中にしか描画できないので、テキスト選択はできない。選択はホストアプリが管理する。ホストの編集メニュー（カット/コピー/ペースト）にもアクセスできない。挿入位置付近にインラインの自動修正 UI も出せない | 【公式・旧】[E] |
| ビュー外への描画 | primary view の上端より上には描画できない（システムキーボードのような最上段キーのポップアップは不可） | 【公式・旧】[E] |
| マイク | Full Access がない場合は「マイクとスピーカーにアクセスできない」。Full Access があっても App Extension は録音できない（後述 §5） | 【公式】[C]、【公式・旧】[E] [L] |
| キーボード一覧 | 有効なキーボードの一覧を取得する API も、特定のキーボードを指定して切り替える API もない | 【公式・旧】[E] |
| 幅 | キーボードの幅は常にシステムが決める（画面幅に一致するのが一般的） | 【公式】[B] |

### 必須要件
- キーボード切り替え手段を必ず用意する。`needsInputModeSwitchKey` が `true` のときだけ自前の地球儀キーを出し、その action に `handleInputModeList(from:with:)` を `.allTouchEvents` で割り当てる（長押しで一覧が出る）【公式】[A]
- コンテナアプリには何らかの実用性が必要（App Store 配布の場合）【公式】[B]

### メモリ上限
- **【公式】** キーボードは別プロセスで動き、メモリ上限を超えるとシステムに終了させられる。上限は機種ごとに異なる。非表示にしてもプロセスが終了するとは限らないので、メモリが解放される前提で設計しないこと。具体的な数値は公表されていない [A]
- **【公式】** jetsam レポートの `per-process-limit` について「App Extension の上限はフォアグラウンドアプリよりかなり低い」[K]
- **【非公式】** 報告されている値（いずれも Apple の数値ではない）:
  - 48 MB: React Native のドキュメント（出典の記載なし、古い記述）[RN]
  - 約 60 MB（phys_footprint）: DEV Community の記事（機種・OS 不明）[DEV]
  - 77 MB（4,928 pages）: iPhone 14 Pro / iOS 27 の jetsam ログに `per-process-limit` として記録 [VOCA]
  - 30〜40 MB: GitHub Discussion の質問者の認識（未検証）
- 設計の目安: 最小報告値（30〜48 MB）を下回るように設計し、実機の jetsam レポートで確認する（この目安は本調査の推奨で、公式値ではない）。

---

## 2. Full Access（`RequestsOpenAccess`）

### 設定
- `Info.plist` の `NSExtension > NSExtensionAttributes > RequestsOpenAccess = true` にしたうえで、ユーザーが「設定」でそのキーボードの「フルアクセスを許可」をオンにする 【公式】[A] [C]
- 状態の判定: `UIInputViewController.hasFullAccess`（iOS 11+、読み取り専用）【公式】[G]

### Full Access なし／あり の差（現行ドキュメント [C]）
| 項目 | Full Access なし（`RequestsOpenAccess=false`、またはユーザーが未許可） | Full Access あり |
|---|---|---|
| 基本的なキーボード機能 | 可 | 可 |
| 共通語レキシコン（`requestSupplementaryLexicon(completion:)` / `UILexicon`）、ユーザー辞書（テキスト置換） | 可 | 可 |
| ファイルシステム | 自分の sandbox コンテナのみ | 同左＋共有コンテナ |
| **App Group 共有コンテナ** | **読み取り専用**（"read-only access to the containing app's shared containers"） | **読み書き可**（"The keyboard and containing app can employ a shared container"） |
| ネットワーク | 不可 | 可 |
| マイク・スピーカー | 不可（"No access to microphone and speaker"） | スピーカー（音声再生）は可。マイク録音は App Extension として不可（§5） |
| 位置情報・連絡先 | 不可 | ユーザー許可があれば可 |
| iCloud / Game Center / App 内課金 | 不可 | iCloud は可。Game Center / App 内課金はコンテナアプリ経由で可 |
| MDM 管理アプリとの連携 | — | 対応していれば可 |

旧ガイド [E] では、Full Access で可能になる項目として次も挙げている（現行 [C] には個別の記載がない）。
- `UIPasteboard` クラスの使用 【公式・旧】
- `playInputClick` を含む音声の再生 【公式・旧】
- カメラロールへのアクセス（ユーザー許可が必要）【公式・旧】

### App Group 共有コンテナ: iOS バージョンによる差
- 旧ガイド [E]（iOS 8 期）は Full Access なしを「No shared container with containing app」としている。現行 [C] は「読み取りは許可」と明記している。
- **【未確認】** 読み取りが許可されるようになった iOS バージョン。Apple の文書に変更履歴がなく特定できない。iOS 18 / 26 では現行 [C] の記述（読み取り専用）に従えばよい。
- **【非公式】** Full Access なしで共有コンテナに書き込むと、エラーにならず黙って失敗するという報告がある [DEV]。
- **【未確認】** Full Access なしで `UserDefaults(suiteName:)` を読むときの信頼性（キャッシュ・同期のタイミング）。読み取りは公式に許可されているが、`UserDefaults` 経由の挙動は文書化されていない。
- 実装方針: 設定・辞書はコンテナアプリが書き込み、キーボードは読むだけにすれば Full Access なしで成立する（[B] の "Leverage your containing app" でも同じ構成が推奨されている）。

### クリック音（`playInputClick`）
- API: `UIDevice.current.playInputClick()`。入力ビュー（`UIInputView` サブクラス）を `UIInputViewAudioFeedback` に準拠させ、`enableInputClicksWhenVisible` で `true` を返す。鳴るのは、ユーザーが設定でキーボードのクリック音を有効にしていて、かつ入力ビューが有効で表示中のときだけ 【公式】[H]
- キーボード拡張では Full Access が必要: 旧ガイド [E] は Full Access で可能になる項目として "Ability to play audio, including keyboard clicks using the playInputClick method" を挙げ、現行 [C] は Full Access なしを "No access to microphone and speaker" としている 【公式】
- **【未確認】** ユーザーの「キーボードのフィードバック > サウンド」の設定値をキーボード側から直接読む公開 API（見つからなかった）。

### ハプティクス（`UIImpactFeedbackGenerator` など）→ §8 参照
- **【未確認（公式記載なし）】** Full Access が必要かどうかは Apple の文書に書かれていない。

---

## 3. Apple Intelligence: 作文ツール（Writing Tools）／ジェン文字（Genmoji）

### 作文ツール
- **ユーザー側の起動方法【公式】[N]（iOS 26 版 iPhone ユーザガイド）**: テキストを選択して Writing Tools ボタンをタップする。「キーボード右上の Writing Tools ボタンからも開ける」とあるが、このボタンは Apple 純正キーボードの UI。
- **開発者側の仕組み【公式】[M]**: `UITextView` / `UITextField` は自動的に対応する。独自ビューは `UIWritingToolsCoordinator` で対応し、その場合「ビューのコンテキストメニューに UIKit が Writing Tools 起動コマンドを自動で追加する」。つまりメニュー項目はホストアプリ（テキストビュー）側の UIKit が出す。ホストは `writingToolsBehavior`（`UITextInputTraits`、iOS 18+）で抑止もできる。プログラムからの起動アクションは `showWritingTools(_:)`（`UIResponderStandardEditActions`、iOS 18.2+）で、ホストの responder chain に属する。
- **サードパーティキーボードから起動: 不可（公開 API なし）**: `UITextDocumentProxy` と `UIInputViewController` に作文ツール関連のメソッドはない [F] [G]。キーボードは別プロセスで、ホストの responder（`showWritingTools(_:)`）を呼ぶ手段もない。UIKit の更新履歴 [T] を見ても、2025年6月（iOS 26）と2026年6月（iOS 27）にキーボード拡張向けの追加はない。
- **カスタムキーボード表示中に、ホストの編集メニューから作文ツールを使えるか: 【未確認】**: メニュー項目はホスト側の UIKit が追加するので使えると推測できる。ただし、カスタムキーボード表示中の挙動を明記した Apple 文書は見つからなかった。iPhone では作文ツールのパネルがキーボード領域を置き換えて表示されるため、その間のカスタムキーボードの扱いも文書化されていない。実機での確認が必要。
- **【未確認】** ホストが設定した `writingToolsBehavior` の値が `textDocumentProxy` 経由で読めるか。プロトコル上は `UITextInputTraits` の optional プロパティだが、proxy に反映されるかは文書化されていない。

### Genmoji と絵文字キーボード
- Genmoji はシステムの絵文字キーボード（右上の「Genmoji」）から作る 【公式】[O]
- Genmoji の実体は `NSAdaptiveImageGlyph`（iOS 18+）で、属性付き文字列の属性として入る。受け入れるにはホストが `supportsAdaptiveImageGlyph` を有効にする必要がある 【公式】[O2]
- **カスタムキーボードから Genmoji を挿入: 不可**。`textDocumentProxy` が挿入できるのは「属性なしの `NSString`」だけ（`insertText(_:)`）【公式】[G]。Unicode 絵文字を文字列として挿入することはできる。
- **絵文字キーボードを直接開く: 不可**。特定のキーボードへ切り替える API はない 【公式・旧】[E]。`advanceToNextInputMode()` は「次の」キーボードに切り替えるだけ。`handleInputModeList(from:with:)` で一覧を出し、ユーザーに「絵文字」を選んでもらうことはできる 【公式】[G]。Face ID 搭載の iPhone では、キーボード下のシステム地球儀キーからも切り替えられる。
- 参考【未確認】: iOS 18.4 で `UITextInputTraits.conversationContext` / `UITextInputDelegate.conversationContext(_:didChange:)`（スマートリプライ用）が追加された。サードパーティキーボードがこれを受け取れるかは文書化されていない。

---

## 4. 編集メニューと `UITextDocumentProxy` でできること

### 編集メニュー（カット/コピー/ペーストの吹き出し）
- ホストアプリのテキストビューが出すもので、**キーボードから開く・操作する API はない** 【公式・旧】[E]

### `textDocumentProxy`（`UIInputViewController.textDocumentProxy`）で使える API【公式】[F] [G] [D]
| API | 導入 | 内容 |
|---|---|---|
| `insertText(_:)`（`UIKeyInput`） | — | 挿入位置に属性なしの文字列を挿入 |
| `deleteBackward()`（`UIKeyInput`） | — | 挿入位置の前を1文字削除 |
| `hasText`（`UIKeyInput`） | — | 入力欄にテキストがあるか |
| `adjustTextPosition(byCharacterOffset:)` | — | 挿入位置を前後に移動（§6） |
| `documentContextBeforeInput` / `documentContextAfterInput` | — | 挿入位置の前後の文脈（`String?`） |
| `selectedText` | iOS 11 | 選択中のテキスト（`String?`） |
| `setMarkedText(_:selectedRange:)` / `unmarkText()` | iOS 13 | 未確定文字列（marked text）の設定と確定 |
| `documentIdentifier` | iOS 11 | ドキュメントを区別する `UUID` |
| `documentInputMode` | iOS 10 | ホストが保存した `UITextInputMode`（`UITextInputMode?`） |
| `keyboardType` / `returnKeyType` / `textContentType` / `keyboardAppearance` / `autocapitalizationType` / `autocorrectionType` / `spellCheckingType` / `smartQuotesType` / `enablesReturnKeyAutomatically` など（`UITextInputTraits`） | — | 入力欄の特性（UI の切り替えに使う） |

そのほかの API:
- `UITextInputDelegate` の `textWillChange(_:)` / `textDidChange(_:)` / `selectionWillChange(_:)` / `selectionDidChange(_:)`（引数は常に `nil`）
- `dismissKeyboard()` / `advanceToNextInputMode()` / `handleInputModeList(from:with:)`
- `primaryLanguage` / `hasDictationKey` / `needsInputModeSwitchKey` / `hasFullAccess`
- `requestSupplementaryLexicon(completion:)`

### コピー／カット／ペースト／全選択
| 操作 | Full Access なし | Full Access あり | 根拠 |
|---|---|---|---|
| システムクリップボードへのコピー | **不可**（`UIPasteboard` が使えない） | 可（`selectedText` を読んで `UIPasteboard.general` に書く） | 【公式・旧】[E] |
| システムクリップボードからのペースト | **不可** | 可（`UIPasteboard` を読んで `insertText`） | 【公式・旧】[E] |
| キーボード内だけのクリップボード | 可（プロセス内メモリや自分のコンテナに保存して `insertText`。他アプリとは共有されない） | 可 | 上記の API と §2 から導いた結論 |
| カット（選択範囲の削除） | 選択範囲を `selectedText` で読み、`deleteBackward()` で消す方法が一般的。選択がある状態の `deleteBackward()` が選択範囲を消すかどうかは、ホストのテキストビューの実装次第で、Apple の文書には書かれていない **【未確認】** | 同左（＋クリップボードへの書き込み） | — |
| 全選択／任意範囲の選択 | **不可**。既存テキストに選択範囲を設定する API はない。`setMarkedText(_:selectedRange:)` の `selectedRange` は未確定文字列の中の選択だけ（"Calling setMarkedText selects the text specified by range"）【公式】[D] | 同左 | 【公式】[E] [F] |
| ホストのアンドゥ/リドゥ | 公開 API なし | 同左 | 【公式】[F]（該当するメソッドがない） |

- **【未確認】** Full Access ありのキーボードが `UIPasteboard` を読むとき、iOS 16 以降の「ペーストを許可」ダイアログが出るか。キーボード拡張に絞った記述は見つからなかった。

---

## 5. 音声入力（Dictation）

- **Face ID 搭載 iPhone の下部バー【公式】[A] [B]**: iOS がキーボードビューの下に地球儀アイコンを自動で表示し、`needsInputModeSwitchKey` を `false` にする（自前の切り替えキーは出さない）。音声入力ボタンも iOS が自動で出すことがある（"for example, on iPhone devices with Face ID"）。
- **`hasDictationKey`（get/set）の記述が文書ごとに食い違っている【公式】**:
  - [B]: `true` にすると「iOS はシステムのボタンを表示しない」
  - API リファレンス [G] と SDK ヘッダ: 「システムの音声入力キーが無効（disabled）状態になる」
  - HIG [J]: 「一部のデバイスでは地球儀キーと音声入力キーがカスタムキーボード使用中もキーボード下に自動表示され、アプリはこれらに影響を与えられない」
  - **【非公式】** iOS 26.x で `viewDidAppear` に `hasDictationKey = true` を設定すると、下部のマイクが消えた（地球儀は残る）という報告がある。`viewDidLoad` で設定した場合は消えなかった [LF]。
- **キーボードからシステム音声入力を起動する API: なし** 【公式】[F] [G]（該当するメソッドがない）
- **【未確認】** カスタムキーボード表示中にユーザーが下部のシステムマイクを押したときの正確な挙動（純正キーボードに切り替わるかなど）。Apple の文書に記述がない。
- **自前の音声認識（拡張内で録音）: 不可**
  - 【公式・旧】[L] QA1872: App Extension は録音できず、`AVAudioRecorder.record()` や `AVAudioEngine`（`inputNode` を使う場合）の開始などがエラーになる。
  - 【公式】[C]: Full Access なしでは "No access to microphone and speaker"。
  - 【非公式】2023年のフォーラム投稿 [F742601] のログ: "NOT allowed to start recording because it is an extension and doesn't have entitlements to record audio"。Full Access を許可しても同様だという報告もある。
  - 回避策として報告されている構成【非公式】: コンテナアプリで録音して文字起こしし、App Group 経由でキーボードに渡す。ただしキーボードからコンテナアプリを開く公式 API はない。`NSExtensionContext.open(_:completionHandler:)` が使えるのは iOS では Today と iMessage 拡張だけ 【公式】[U]

---

## 6. カーソル移動と文脈取得

- `adjustTextPosition(byCharacterOffset:)` 【公式】[F]: 引数は「移動する文字数」。正の値は現在の言語の text storage direction で前方、負の値は後方へ動く。
  - **単位**: Apple は「character」としか書いておらず、UTF-16 なのか書記素クラスタなのかは定義されていない **【未確認（公式）】**。SDK ヘッダにも説明がない [HDR]。
  - **【非公式】** UTF-16 コード単位（`String.utf16.count`）で数えると合うという報告が複数ある [F133403] [FCITX]。絵文字や結合文字（濁点の結合形など）をまたぐときは、`Character` の数ではなく UTF-16 長で移動するのが安全。
- **行の上下移動**: 縦方向に動かす API はない 【公式】[F]（該当するメソッドがない）。改行も1文字として横方向に移動し、文脈文字列から列位置を計算して実装する必要がある【非公式】[FCITX]
- **文脈の更新は非同期**【非公式】: `adjustTextPosition` を呼んだ直後は `documentContextBeforeInput` がまだ更新されておらず、少し待つ必要があったという報告がある [FCITX]。
- **文脈の長さ**: Apple は上限を書いていない **【未確認（公式）】**。
  - 【非公式】段落の途中では約300文字しか返らなかった [GIST]。
  - 【非公式】ホストによっては改行で切れる [LILF]。
  - 【非公式】文書全体が必要なら、カーソルを少しずつ動かして読む手法がある（Fleksy SDK の `readFullDocumentContext`。読み取り中は入力をブロックする必要がある）[FLEKSY]。
- **未確定文字列（marked text）との関係**:
  - 【公式】`setMarkedText` は既存の未確定文字列を置き換える。未確定文字列がなければ、現在の選択位置に挿入する。`unmarkText()` は未確定の表示を外してテキストを残す [D] [F]。
  - **【未確認】** 未確定文字列があるときに `adjustTextPosition` を呼んだ場合の挙動（範囲内を動くのか、確定されるのか）。文書化されていない。実装では移動の前に `unmarkText()`（または確定文字列の `insertText`）を呼ぶ方が安全（本調査の推奨）。
  - **【未確認】** 選択範囲がある状態で `adjustTextPosition` を呼んだときの挙動。

---

## 7. キーボードの高さ・横向き・フローティング／片手モード

- **既定**: 画面サイズと向きに合わせて、システムキーボードと同じ高さになる。幅はシステムが決める 【公式】[B] [E]
- **高さの変更【公式】[B] [E]**: Auto Layout で `UIInputViewController` の view（`inputView`）の高さ制約を変える。旧ガイドは「primary view が最初に描画された後なら、いつでも変更できる」としている。
- **priority 999**: Apple の文書には書かれていない **【非公式】**。システムが付ける高さ制約とぶつかって警告が出るのを避けるため、自前の高さ制約の priority を 999 にする手法が一般的に使われている。キーボード拡張で必要かどうかは公式に確認できない。
- `UIInputView.allowsSelfSizing`（iOS 9+）【公式】[V]: `true` にすると、UIKit が入力ビューの `systemLayoutSizeFitting(_:)` の値に従う。ただしキーボード拡張で試しても効かなかったという報告がある【非公式】[F813579]
- **既知の問題（ちらつき）**:
  - 【公式・Apple 社員の回答】2025年9月、Apple の Worldwide Developer Relations 担当者が iOS 26 で再現を確認した。システムが大きめの初期高さを与え、表示後に変更するのが原因で、「拡張が高さを変えられるのは primary view が最初に描画された後だけで、表示前に高さを調整してちらつきを避ける方法はない」と回答し、Feedback での報告を勧めた [F799003]。
  - 【非公式】iOS 17 / 18 / 26.2 で、0×0 → 全画面 → 中間 → 目標値と段階的にリサイズされるという報告がある。iOS 27 で直ったという利用者の報告も1件ある [F813579]。
- **横向き**: 縦と横の両方、compact と regular の両方の幅に対応し、幅は表示中にも変わり得る前提で作る 【公式】[A]。独自の高さを使う場合は、向きやサイズクラスが変わるたびに制約の値を更新する必要がある（高さ制約を自前で持つことからの帰結）。
- **iPad のフローティング**: 「iPadOS ではフローティング表示でもテストすること」とあり、カスタムキーボードもフローティング（compact 幅）で表示される 【公式】[A] [B]
- **iPhone の片手入力（システムの片手モード）**: 純正キーボードでは、絵文字キーまたは地球儀キーを長押しして左右寄せのレイアウトを選ぶ 【公式】[P]
  - カスタムキーボード向けに、システムの片手モードを使う・検知する公開 API は**ない** 【公式】[G]（該当するメソッドがない）。必要なら自前のレイアウトとして実装する。
  - **【未確認】** カスタムキーボード表示中に、システム下部バーの地球儀キーを長押ししたメニューに片手レイアウトの選択肢が出るか、出た場合に効くか。文書に記述がない。

---

## 8. Full Access なしでのハプティクス（最近の iOS）

- **【公式】** Apple の文書（[C] [E]、`UIFeedbackGenerator` のリファレンス）に、キーボード拡張でのハプティクスと Full Access の関係は**書かれていない**。
- **【非公式】報告は割れている**:
  - 「Full Access を有効にしないとフィードバックが発生しない」: 2016年のフォーラム投稿 [F63493]。返信はなく、Apple の回答もない。
  - App Store のキーボードアプリの説明文「キーボード設定でフルアクセスを許可すると触覚フィードバックを感じられます」[CAT]
  - 「`UIImpactFeedbackGenerator` には許可が要らない」とする記事もある（機種・OS の記載なし）[DEV]
- **【非公式】** キーボード拡張からは、iOS 16 以降の「サウンドと触覚 > キーボードのフィードバック > 触覚」の設定値を読めないので、自前で設定を持つという実装報告がある。公開 API が見当たらない点は本調査でも同じ。
- **結論**: iOS 18 / 26 で Full Access なしでも鳴るかは **【未確認】**。Full Access がないと鳴らない前提で設計し（鳴らなくても動作に支障がないようにする）、実機で `hasFullAccess` の true / false 両方を確認する。

---

## 9. 無料（Personal Team）アカウントと App Groups

- **【公式】[R] Supported capabilities (iOS)** の「Apple Developer」列（無料。Apple Developer Agreement に同意した Apple Account で、アプリの配布はできない）で利用できる capability:
  - **App groups** ✓
  - Background modes
  - Data protection
  - HealthKit
  - HomeKit
  - Inter-App Audio
  - Keychain sharing
  - Maps（MapKit は使えるが経路案内は不可）
  - Wireless Accessory Configuration
- 無料では使えない主なもの: Push notifications、iCloud（CloudKit・iCloud Documents・Key-Value Storage）、Associated domains、Siri、Sign in with Apple、App 内課金、Game Center、Apple Pay、Network extensions、Personal VPN、AutoFill credential provider、Time Sensitive Notifications など。
- **キーボード拡張自体と `RequestsOpenAccess` は capability ではない**（`Info.plist` の設定）ので、無料アカウントでも設定できる。§2 のとおり、Full Access を許可しないと App Group は読み取り専用になる点は変わらない。
- 注意: iCloud が無料では使えないので、Full Access でできる「iCloud 経由の設定同期」は無料アカウントでは実質使えない（上の表からの帰結）。

---

## 10. 無料プロビジョニングの制限

- **【公式】[S] About your developer account（Personal Team）**:
  - App ID は最大10個まで登録でき、各 App ID は7日で失効する。
  - 登録できるデバイスは最大3台で、7日で失効する。
  - **1デバイスにインストールできるアプリは最大3個**。
  - デバイスにインストールするためのプロビジョニングプロファイルは**発行から7日で失効**し、失効後は再ビルドと再インストールが必要。
- **App Extension と App ID**: 拡張には拡張ごとのバンドル ID（App ID）が必要なので、コンテナアプリ＋キーボードで App ID を2個使う。【非公式】AltStore の FAQ にも「必要な App ID の数は含まれる App Extension の数で決まる」とある [ALT1]
- **3アプリ制限に App Extension が含まれるか**:
  - 【公式】Apple の文書は「3 apps per device」としか書いておらず、拡張の扱いは明記していない → **【未確認（公式）】**
  - 【非公式】AltStore の PR #129 は「iOS 13.3.1 limits free developer accounts to 3 apps and app extensions」「Free developer accounts may only have 3 active apps and app extensions」としている [ALT2]。これに従うと、キーボードアプリ1本（アプリ＋拡張）で3枠のうち2枠を使う。
- 運用上の注意: 7日ごとに Xcode から再ビルドして再インストールする必要がある。App ID の枠は7日で回復するが、拡張を追加したりバンドル ID を変えたりすると消費が増える。

---

## まとめ表（可能 / 不可能 / 条件付き）

| 項目 | 判定 | 条件・備考 |
|---|---|---|
| 文字の挿入・削除（`insertText` / `deleteBackward`） | 可能 | — |
| 未確定文字列（`setMarkedText` / `unmarkText`） | 可能 | iOS 13+ |
| 前後の文脈・選択テキストの取得 | 条件付き | 長さの上限は非公開。約300文字や改行での切れが報告されている |
| カーソルの左右移動（`adjustTextPosition`） | 可能 | 単位は非公式情報では UTF-16。文脈の更新は非同期 |
| カーソルの上下（行）移動 | 不可能（API なし） | 文脈から自前で計算すれば近似できる |
| テキスト選択・全選択 | 不可能 | 未確定文字列内の選択だけ可 |
| ホストの編集メニューを開く | 不可能 | — |
| システムクリップボードのコピー・ペースト | 条件付き | Full Access が必要（`UIPasteboard`） |
| キーボード内だけのクリップボード | 可能 | 他アプリとは共有されない |
| パスワード欄・電話番号パッド・拒否アプリでの入力 | 不可能 | システムキーボードに置き換わる |
| ネットワーク通信 | 条件付き | Full Access が必要 |
| App Group の読み取り | 可能 | Full Access なしでも読み取り専用で可（現行の公式記述） |
| App Group への書き込み | 条件付き | Full Access が必要 |
| クリック音（`playInputClick`） | 条件付き | Full Access、`UIInputViewAudioFeedback` の実装、ユーザー設定の三つが必要 |
| ハプティクス | 条件付き（未確認） | 公式記載なし。非公式には Full Access が必要という報告が多い |
| マイク録音・自前の音声認識（拡張内） | 不可能 | Full Access があっても不可 |
| システム音声入力ボタンの表示・非表示 | 条件付き | `hasDictationKey`。文書間で記述が食い違う。非公式には `viewDidAppear` で true にすると消える |
| システム音声入力の起動 | 不可能 | — |
| 作文ツールをキーボードから起動 | 不可能 | API なし（iOS 18 / 26 / 27） |
| ホストの編集メニューから作文ツールを使う（カスタムキーボード表示中） | 未確認 | ホスト側の機能なので使える可能性が高いが、要実機確認 |
| Genmoji の挿入 | 不可能 | `insertText` は属性なし文字列のみ |
| 絵文字キーボードへの直接切り替え | 不可能 | 一覧表示（`handleInputModeList`）でユーザーに選んでもらうことは可 |
| 高さの変更 | 条件付き | 高さ制約で変更できるが、表示時のちらつきは回避できない（Apple 社員の回答） |
| iPad のフローティング | 可能 | システムが compact 幅で表示する |
| iPhone のシステム片手モード | 不可能（API なし） | 自前のレイアウトで代替 |
| 無料アカウントで App Groups | 可能 | 公式の capability 表で ✓ |
| 無料アカウントで iCloud・Push | 不可能 | — |
| 無料プロビジョニング | 条件付き | 7日で失効、App ID は7日で10個まで、1デバイス3アプリまで（拡張も数に含まれる可能性が高い。非公式） |

---

## 出典一覧

### Apple 公式（developer.apple.com）
- [A] Creating a custom keyboard — https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- [B] Configuring a custom keyboard interface — https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface
- [C] Configuring open access for a custom keyboard — https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- [D] Handling text interactions in custom keyboards — https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards
- [E] App Extension Programming Guide: Custom Keyboard（アーカイブ／iOS 8 期）— https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- [F] UITextDocumentProxy — https://developer.apple.com/documentation/uikit/uitextdocumentproxy
  - adjustTextPosition(byCharacterOffset:) — https://developer.apple.com/documentation/uikit/uitextdocumentproxy/adjusttextposition(bycharacteroffset:)
  - selectedText — https://developer.apple.com/documentation/uikit/uitextdocumentproxy/selectedtext
  - setMarkedText(_:selectedRange:) — https://developer.apple.com/documentation/uikit/uitextdocumentproxy/setmarkedtext(_:selectedrange:)
  - documentIdentifier — https://developer.apple.com/documentation/uikit/uitextdocumentproxy/documentidentifier
  - documentInputMode — https://developer.apple.com/documentation/uikit/uitextdocumentproxy/documentinputmode
- [G] UIInputViewController — https://developer.apple.com/documentation/uikit/uiinputviewcontroller
  - hasFullAccess — https://developer.apple.com/documentation/uikit/uiinputviewcontroller/hasfullaccess
  - needsInputModeSwitchKey — https://developer.apple.com/documentation/uikit/uiinputviewcontroller/needsinputmodeswitchkey
  - hasDictationKey — https://developer.apple.com/documentation/uikit/uiinputviewcontroller/hasdictationkey
  - handleInputModeList(from:with:) — https://developer.apple.com/documentation/uikit/uiinputviewcontroller/handleinputmodelist(from:with:)
  - dismissKeyboard() — https://developer.apple.com/documentation/uikit/uiinputviewcontroller/dismisskeyboard()
- [H] playInputClick() — https://developer.apple.com/documentation/uikit/uidevice/playinputclick() ／ enableInputClicksWhenVisible — https://developer.apple.com/documentation/uikit/uiinputviewaudiofeedback/enableinputclickswhenvisible
- [I] application(_:shouldAllowExtensionPointIdentifier:) — https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:shouldallowextensionpointidentifier:) ／ ExtensionPointIdentifier.keyboard — https://developer.apple.com/documentation/uikit/uiapplication/extensionpointidentifier/keyboard
- [J] HIG: Virtual keyboards（Custom keyboards）— https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards
- [K] Identifying high-memory use with jetsam event reports — https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports
- [L] Technical Q&A QA1872: Recording Audio from an App Extension（2014）— https://developer.apple.com/library/archive/qa/qa1872/_index.html
- [M] Writing Tools — https://developer.apple.com/documentation/uikit/writing-tools ／ Adding Writing Tools support to a custom UIView — https://developer.apple.com/documentation/uikit/adding-writing-tools-support-to-a-custom-uiview ／ writingToolsBehavior — https://developer.apple.com/documentation/uikit/uitextinputtraits/writingtoolsbehavior ／ showWritingTools(_:) — https://developer.apple.com/documentation/uikit/uiresponderstandardeditactions/showwritingtools(_:)
- [O2] NSAdaptiveImageGlyph — https://developer.apple.com/documentation/uikit/nsadaptiveimageglyph ／ supportsAdaptiveImageGlyph — https://developer.apple.com/documentation/uikit/uitextinput/supportsadaptiveimageglyph
- [R] Supported capabilities (iOS) — https://developer.apple.com/help/account/reference/supported-capabilities-ios
- [S] About your developer account（Personal Team の制限）— https://developer.apple.com/help/account/basics/about-your-developer-account
- [T] UIKit updates — https://developer.apple.com/documentation/updates/uikit
- [U] NSExtensionContext.open(_:completionHandler:) — https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)
- [V] UIInputView.allowsSelfSizing — https://developer.apple.com/documentation/uikit/uiinputview/allowsselfsizing
- conversationContext（iOS 18.4）— https://developer.apple.com/documentation/uikit/uitextinputtraits/conversationcontext

### Apple 公式（support.apple.com、iOS 26 版 iPhone ユーザガイド）
- [N] 作文ツール — https://support.apple.com/guide/iphone/writing-tools-write-improve-summarize-iph6f08da1d2/26.0/ios/26.0
- [O] Genmoji — https://support.apple.com/guide/iphone/create-your-own-emoji-with-genmoji-iph4e76f5667/26.0/ios/26.0
- [P] オンスクリーンキーボード（片手入力、キーボードのフィードバック）— https://support.apple.com/guide/iphone/type-with-the-onscreen-keyboard-iph3c50f96e/26.0/ios/26.0
- [Q] 音声入力 — https://support.apple.com/guide/iphone/dictate-text-iph2c0651d2/26.0/ios/26.0

### Apple Developer Forums（ユーザー投稿。Apple 社員の回答はその旨を明記）
- [F799003] Custom Keyboard help（2025年9月、WWDR 担当者が回答）— https://developer.apple.com/forums/thread/799003
- [F813579] How to set custom height for keyboard extension without resize flicker?（2026年）— https://developer.apple.com/forums/thread/813579
- [F63493] Using haptic feedback in keyboard extensions（2016年、返信なし）— https://developer.apple.com/forums/thread/63493
- [F742601] Recording audio in keyboard extension（2023年、返信なし）— https://developer.apple.com/forums/thread/742601
- [F133403] How to replace emoji text using textDocumentProxy（2020年、コミュニティ回答）— https://developer.apple.com/forums/thread/133403

### 第三者（非公式）
- [HDR] iOS 18 SDK `UIInputViewController.h`（第三者によるヘッダのミラー。Xcode 同梱の SDK ヘッダで再確認を推奨）— https://github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS18.0.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIInputViewController.h
- [DEV] The three hard constraints of an iOS keyboard extension — https://dev.to/tbds_2dadf2b626f315902eae/the-three-hard-constraints-of-an-ios-keyboard-extension-46af
- [VOCA] VocaHQ/vocaphone PR #340（jetsam ログ）— https://github.com/VocaHQ/vocaphone/pull/340
- [RN] React Native: App Extensions — https://reactnative.dev/docs/app-extensions
- [GIST] UITextDocumentProxy gist のコメント（約300文字の制限）— https://gist.github.com/wearhere/f46ab9d837acaeaabfa86a813c44ad25?permalink_comment_id=5191040
- [LILF] lilfeelz/keyboard issue #34（改行で切れる）— https://github.com/lilfeelz/keyboard/issues/34
- [FCITX] fcitx5-ios PR #143（上下移動、UTF-16、遅延）— https://github.com/fcitx-contrib/fcitx5-ios/pull/143
- [FLEKSY] Fleksy SDK KeyboardViewController（readFullDocumentContext）— https://docs.fleksy.com/sdk-ios/api-reference-ios/keyboardviewcontroller
- [LF] LocalFlow PR #34（hasDictationKey）— https://github.com/ajbarryiii/LocalFlow/pull/34
- [CAT] CatKeyboard の App Store 説明文 — https://apps.apple.com/py/app/catkeyboard/id1636890042
- [ALT1] AltStore FAQ: App IDs — https://faq.altstore.io/altstore-classic/app-ids
- [ALT2] AltStore PR #129（3 active apps and app extensions）— https://github.com/altstoreio/AltStore/pull/129
