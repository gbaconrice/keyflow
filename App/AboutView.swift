import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("入力した文字は端末の外に送りません。KeyFlowには通信機能がなく、広告や利用状況の収集もありません。")
                Text("変換の学習データはキーボードの中に保存されます。消去は「変換と学習」からできます。")
            } header: {
                Text("プライバシー")
            }

            Section {
                limitation("パスワードと電話番号の入力欄", "iOSの標準キーボードに自動で切り替わります。")
                limitation("一部のアプリ", "アプリ側でカスタムキーボードを禁止している場合は使えません。")
                limitation("コピー・ペーストとテキストの選択", "入力欄を長押ししたときのメニューは、これまでどおり使えます。キーボードからこのメニューは開けません。ペーストボタンはクリップボードの読み取りにフルアクセスが必要なため、置いていません。")
                limitation("作文ツール（Apple Intelligence）", "キーボードからは呼び出せません。テキストを選択したときのメニューから使ってください。")
                limitation("音声入力", "カスタムキーボードはマイクを使えません。地球儀キーで標準キーボードに切り替えて使ってください。")
                limitation("絵文字キーボード", "直接は開けません。地球儀キーで切り替えるか、読みを入力して候補から選んでください（例:「ねこ」）。")
                limitation("カーソルの上下移動", "iOSには上下に動かす仕組みがありません。左右の移動と、空白キーを横にドラッグする操作で代わりにしています。")
            } header: {
                Text("iOSの制限でできないこと")
            }
        }
        .navigationTitle("プライバシーとiOSの制限")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func limitation(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct LicensesView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let note: String
    }

    private let items: [Item] = [
        Item(name: "AzooKeyKanaKanjiConverter", license: "MIT License", note: "Copyright (c) 2023 Miwa / Ensan\nかな漢字変換エンジン、ローマ字の変換表"),
        Item(name: "azooKey_dictionary_storage", license: "Apache License 2.0", note: "変換辞書データ"),
        Item(name: "azooKey_emoji_dictionary_storage", license: "azooKeyの一部として配布", note: "絵文字辞書データ"),
        Item(name: "swift-algorithms / swift-collections / swift-numerics", license: "Apache License 2.0", note: "Copyright (c) Apple Inc."),
        Item(name: "swift-tokenizers", license: "Apache License 2.0", note: "変換エンジンが依存"),
        Item(name: "Jinja", license: "MIT License", note: "Copyright (c) 2024 John Mai\n変換エンジンが依存"),
    ]

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.bold())
                Text(item.license).font(.footnote)
                Text(item.note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}
