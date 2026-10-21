import SwiftUI
import KeyFlowCore

@main
struct KeyFlowApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                // UIテストでダークモードの画面を撮るための起動引数
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-KeyFlowForceDark") ? .dark : nil)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SetupView()
                    } label: {
                        Label("キーボードを追加する", systemImage: "keyboard.badge.ellipsis")
                    }
                    NavigationLink {
                        TryOutView()
                    } label: {
                        Label("試し打ち", systemImage: "character.cursor.ibeam")
                    }
                }

                Section("キーボード") {
                    NavigationLink {
                        LayoutSettingsView()
                    } label: {
                        Label("サイズと配置", systemImage: "rectangle.expand.vertical")
                    }
                    NavigationLink {
                        InputSettingsView()
                    } label: {
                        Label("入力操作", systemImage: "hand.tap")
                    }
                    NavigationLink {
                        FeedbackSettingsView()
                    } label: {
                        Label("振動と音", systemImage: "waveform")
                    }
                }

                Section("変換") {
                    NavigationLink {
                        ConversionSettingsView()
                    } label: {
                        Label("変換と学習", systemImage: "character.book.closed")
                    }
                    NavigationLink {
                        UserDictionaryView()
                    } label: {
                        Label("ユーザー辞書", systemImage: "text.book.closed")
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("プライバシーとiOSの制限", systemImage: "lock.shield")
                    }
                    NavigationLink {
                        LicensesView()
                    } label: {
                        Label("ライセンス", systemImage: "doc.text")
                    }
                } footer: {
                    Text("KeyFlow \(AppModel.appVersion)")
                }
            }
            .navigationTitle("KeyFlow")
        }
    }
}
