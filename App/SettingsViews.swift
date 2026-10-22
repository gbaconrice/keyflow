import SwiftUI
import KeyFlowCore

/// 数値の設定項目（スライダー）
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0.rounded()))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

/// 設定画面の下にプレビューを固定表示する
struct PreviewedSettings<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KeyboardPreviewPanel()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LayoutSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PreviewedSettings(title: "サイズと配置") {
            Section("高さ") {
                SliderRow(title: "キーの領域（縦画面）", value: $model.settings.portraitKeyAreaHeight, range: KeyboardSettings.Ranges.portraitKeyAreaHeight)
                SliderRow(title: "キーの領域（横画面）", value: $model.settings.landscapeKeyAreaHeight, range: KeyboardSettings.Ranges.landscapeKeyAreaHeight)
                SliderRow(title: "候補バー", value: $model.settings.candidateBarHeight, range: KeyboardSettings.Ranges.candidateBarHeight)
            }
            Section("キー") {
                SliderRow(title: "横の間隔", value: $model.settings.horizontalKeySpacing, range: KeyboardSettings.Ranges.horizontalKeySpacing)
                SliderRow(title: "縦の間隔", value: $model.settings.verticalKeySpacing, range: KeyboardSettings.Ranges.verticalKeySpacing)
                SliderRow(title: "左右の余白", value: $model.settings.sideMargin, range: KeyboardSettings.Ranges.sideMargin)
                SliderRow(title: "下の余白", value: $model.settings.bottomMargin, range: KeyboardSettings.Ranges.bottomMargin)
                SliderRow(title: "端の列の幅", value: $model.settings.sideColumnRatio, range: KeyboardSettings.Ranges.sideColumnRatio, step: 0.02) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow(title: "角の丸み", value: $model.settings.keyCornerRadius, range: KeyboardSettings.Ranges.keyCornerRadius)
                SliderRow(title: "文字の大きさ", value: $model.settings.kanaFontSize, range: KeyboardSettings.Ranges.kanaFontSize)
                SliderRow(title: "候補の文字の大きさ", value: $model.settings.candidateFontSize, range: KeyboardSettings.Ranges.candidateFontSize)
            }
            Section {
                HStack {
                    Text("片手モード")
                    Spacer()
                    Picker("片手モード", selection: $model.settings.oneHandedMode) {
                        Text("左手").tag(OneHandedMode.left)
                        Text("オフ").tag(OneHandedMode.off)
                        Text("右手").tag(OneHandedMode.right)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                SliderRow(title: "片手モードの幅", value: $model.settings.oneHandedWidthRatio, range: KeyboardSettings.Ranges.oneHandedWidthRatio, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow(title: "横画面の幅", value: $model.settings.landscapeWidthRatio, range: KeyboardSettings.Ranges.landscapeWidthRatio, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            } header: {
                Text("片手・横画面")
            } footer: {
                Text("片手モードはキーボードの候補バーにある調整ボタンからも切り替えられます。プレビューは縦画面の表示です。")
            }
            Section {
                Button("サイズと配置を初期値に戻す", role: .destructive) {
                    var s = model.settings
                    let d = KeyboardSettings.default
                    s.portraitKeyAreaHeight = d.portraitKeyAreaHeight
                    s.landscapeKeyAreaHeight = d.landscapeKeyAreaHeight
                    s.candidateBarHeight = d.candidateBarHeight
                    s.horizontalKeySpacing = d.horizontalKeySpacing
                    s.verticalKeySpacing = d.verticalKeySpacing
                    s.sideMargin = d.sideMargin
                    s.bottomMargin = d.bottomMargin
                    s.sideColumnRatio = d.sideColumnRatio
                    s.keyCornerRadius = d.keyCornerRadius
                    s.kanaFontSize = d.kanaFontSize
                    s.candidateFontSize = d.candidateFontSize
                    s.oneHandedMode = d.oneHandedMode
                    s.oneHandedWidthRatio = d.oneHandedWidthRatio
                    s.landscapeWidthRatio = d.landscapeWidthRatio
                    model.settings = s
                }
            }
        }
    }
}

struct InputSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PreviewedSettings(title: "入力操作") {
            Section {
                Picker("日本語の配列", selection: $model.settings.kanaLayout) {
                    Text("12キー（フリック）").tag(KanaLayout.flick)
                    Text("ローマ字（QWERTY）").tag(KanaLayout.romaji)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("日本語の配列")
            } footer: {
                Text("ローマ字では、nの次に母音以外を打つと「ん」になります。母音の前の「ん」は nn と打ちます。")
            }
            Section {
                SliderRow(title: "フリックの判定距離", value: $model.settings.flickThreshold, range: KeyboardSettings.Ranges.flickThreshold) { "\(Int($0.rounded())) pt" }
                Toggle("押している間、フリック先を表示", isOn: $model.settings.showsFlickGuide)
                Toggle("キーの四隅にフリック先を表示", isOn: $model.settings.showsKeyHints)
            } header: {
                Text("フリック")
            } footer: {
                Text("小さくすると短い動きでフリックになります。タップがフリックと判定されやすいときは大きくしてください。")
            }
            Section {
                Toggle("連打で文字を切り替える", isOn: $model.settings.toggleInputEnabled)
                if model.settings.toggleInputEnabled {
                    SliderRow(title: "自動で次の文字に進む", value: $model.settings.toggleTimeout, range: KeyboardSettings.Ranges.toggleTimeout, step: 0.1) {
                        $0 <= 0 ? "しない" : String(format: "%.1f秒", $0)
                    }
                }
            } header: {
                Text("トグル入力")
            } footer: {
                Text("オンのとき、「あ」を2回打つと「い」になります。同じ文字を続けて打つときは ▶ キーで区切ります。フリックだけで入力するならオフにしてください。")
            }
            Section("キー") {
                Picker("空白キー", selection: $model.settings.spaceWidth) {
                    Text("半角").tag(SpaceWidth.half)
                    Text("全角").tag(SpaceWidth.full)
                }
                SliderRow(title: "削除の連続が始まるまで", value: $model.settings.deleteRepeatDelay, range: KeyboardSettings.Ranges.deleteRepeatDelay, step: 0.05) { String(format: "%.2f秒", $0) }
                SliderRow(title: "空白キーでのカーソル移動の細かさ", value: $model.settings.cursorDragStep, range: KeyboardSettings.Ranges.cursorDragStep) { "\(Int($0.rounded())) pt" }
                Picker("英字の配列", selection: $model.settings.englishLayout) {
                    Text("QWERTY").tag(EnglishLayout.qwerty)
                    Text("12キー（フリック）").tag(EnglishLayout.flick)
                }
                Toggle("英字の文頭を大文字にする", isOn: $model.settings.englishAutoCapitalization)
                Toggle("英字で単語の候補を出す", isOn: $model.settings.englishSuggestionsEnabled)
            }
            Section {
                Toggle("入力中の文字に下線を付ける", isOn: $model.settings.usesMarkedText)
            } header: {
                Text("互換性")
            } footer: {
                Text("通常はオンのままにしてください。入力中の文字が消える・重なるなど、特定のアプリで表示がおかしいときだけオフにします。")
            }
        }
    }
}

struct FeedbackSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("振動", isOn: $model.settings.hapticFeedback)
                Toggle("クリック音", isOn: $model.settings.keySound)
            } footer: {
                Text("どちらもフルアクセスをオンにしたときに使えます。クリック音はiOSの「設定」→「サウンドと触覚」→「キーボードのフィードバック」にも従います。")
            }
        }
        .navigationTitle("振動と音")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConversionSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmingReset = false
    @State private var resetRequested = false

    var body: some View {
        Form {
            Section {
                Toggle("予測変換", isOn: $model.settings.predictionEnabled)
                Toggle("確定後に次の語を予測", isOn: $model.settings.nextWordPredictionEnabled)
                Toggle("絵文字を候補に出す", isOn: $model.settings.emojiCandidates)
                Toggle("選択したテキストを変換し直す", isOn: $model.settings.reconversionEnabled)
            } header: {
                Text("候補")
            } footer: {
                Text("「変換」キーは予測候補を飛ばし、入力した読みの変換候補だけを順に選びます。テキストを選択すると、候補バーに変換し直す候補が出ます。")
            }
            Section {
                Toggle("確定した候補を学習する", isOn: $model.settings.learningEnabled)
                Button("学習した内容を消去", role: .destructive) {
                    confirmingReset = true
                }
                .disabled(!model.isSharedAvailable)
            } header: {
                Text("学習")
            } footer: {
                if !model.isSharedAvailable {
                    Text("設定を共有できない状態のため、ここからは消去できません。")
                } else if resetRequested {
                    Text("次にキーボードを開いたときに消去します。")
                } else {
                    Text("学習データはキーボードの中だけに保存され、外部には送られません。")
                }
            }
        }
        .navigationTitle("変換と学習")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("学習した内容を消去しますか？", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("消去", role: .destructive) {
                model.requestLearningReset()
                resetRequested = true
            }
        } message: {
            Text("変換候補の並び順が初期の状態に戻ります。ユーザー辞書は消えません。")
        }
    }
}
