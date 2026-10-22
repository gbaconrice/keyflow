import SwiftUI

/// 操作のヒント。見た目では分かりにくい操作をまとめる。
struct UsageGuideView: View {
    private struct Tip: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    private struct TipSection: Identifiable {
        var id: String { title }
        let title: String
        let tips: [Tip]

        init(_ title: String, _ tips: [Tip]) {
            self.title = title
            self.tips = tips
        }
    }

    private let sections: [TipSection] = [
        TipSection("文字の入力", [
            Tip(title: "フリック", detail: "キーを押したまま上下左右にずらします。長押しすると、フリック先の文字が十字に表示されます。"),
            Tip(title: "同じ文字を続けて打つ", detail: "連打で文字を切り替える設定のときは、▶ キーで区切ってから打ちます。"),
            Tip(title: "小゛゜キー", detail: "タップで「か→が」「は→ば→ぱ」「つ→っ→づ」の順に切り替わります。左にフリックで濁点、上で小文字、右で半濁点を直接付けます。"),
            Tip(title: "、。?! キー", detail: "タップで「、」、左「。」、上「？」、右「！」、下「…」です。"),
            Tip(title: "ローマ字入力", detail: "「入力操作」の「日本語の配列」でローマ字（QWERTY）に切り替えられます。キーボードの調整ボタンからも切り替えられます。「、」「。」キーを上にフリックすると「？」「！」です。"),
        ]),
        TipSection("変換", [
            Tip(title: "変換・次候補", detail: "空白キーで変換し、もう一度押すと次の候補に進みます。予測候補は飛ばします。"),
            Tip(title: "一部だけ変換する", detail: "入力中に ◀ を押すと、カーソルより前の部分だけが変換の対象になります。確定すると残りの入力が続きます。"),
            Tip(title: "選び直す", detail: "確定した直後は、候補バーの「取消」で読みに戻せます。テキストを選択すると、変換し直す候補が出ます。"),
            Tip(title: "覚えた候補を消す", detail: "候補を長押しすると、その候補の学習を取り消せます。"),
            Tip(title: "英字の候補", detail: "英字で打っている単語の候補が候補バーに出ます。タップすると単語が置き換わり、空白が入ります。"),
        ]),
        TipSection("カーソル", [
            Tip(title: "空白キーでカーソル移動", detail: "空白キーを左右にドラッグするか、長押ししてから動かします。"),
            Tip(title: "◀ ▶ キー", detail: "入力中でないときは入力欄のカーソルを1文字ずつ動かします。長押しで連続して動きます。"),
        ]),
        TipSection("キーボードの調整", [
            Tip(title: "その場で調整", detail: "候補バー右側のスライダーのボタンから、日本語の配列・高さ・片手モード・フリックの判定距離を変えられます。"),
            Tip(title: "記号・顔文字", detail: "候補バーの顔のボタンから一覧を開きます。"),
        ]),
    ]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.tips) { tip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title).font(.subheadline.bold())
                            Text(tip.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("使い方")
        .navigationBarTitleDisplayMode(.inline)
    }
}
