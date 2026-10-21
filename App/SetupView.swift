import SwiftUI
import UIKit
import KeyFlowCore

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                step(1, "下のボタンで「設定」を開きます。")
                step(2, "「キーボード」をタップし、「KeyFlow」をオンにします。")
                step(3, "文字を入力するときに地球儀キーを長押しし、「KeyFlow」を選びます。")
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("設定を開く", systemImage: "gear")
                }
            } header: {
                Text("キーボードを追加する")
            } footer: {
                Text("「設定」→「一般」→「キーボード」→「キーボード」→「新しいキーボードを追加」からも追加できます。")
            }

            Section {
                Text("フルアクセスはオフのままで使えます。オンにすると、クリック音と振動が使えるようになります。")
                Text("KeyFlowには通信機能がありません。フルアクセスをオンにしても、入力した内容が外部に送られることはありません。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("フルアクセスについて")
            }

            Section {
                LabeledContent("設定の共有") {
                    Text(model.isSharedAvailable ? "使用可能" : "使用不可")
                        .foregroundStyle(model.isSharedAvailable ? Color.green : Color.orange)
                }
                if let id = model.appGroupIdentifier {
                    LabeledContent("App Group", value: id)
                        .font(.footnote)
                }
            } header: {
                Text("状態")
            } footer: {
                if model.isSharedAvailable {
                    Text("このアプリで変えた設定とユーザー辞書は、次にキーボードを開いたときに反映されます。")
                } else {
                    Text("署名の設定により、アプリとキーボードの間で設定を共有できません。サイズなどはキーボードの候補バーにある調整ボタンから変更してください。ユーザー辞書はこの状態では使えません。")
                }
            }
        }
        .navigationTitle("キーボードを追加する")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}

/// 実際にKeyFlowキーボードで打ってみる画面
struct TryOutView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text)
                .focused($focused)
                .frame(minHeight: 160)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            Text("KeyFlowに切り替わらないときは、地球儀キーを長押しして選んでください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("試し打ち")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("消去") { text = "" }
                    .disabled(text.isEmpty)
            }
        }
        .onAppear { focused = true }
    }
}
