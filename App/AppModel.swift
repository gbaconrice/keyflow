import SwiftUI
import KeyFlowCore

/// アプリ全体の状態。設定とユーザー辞書をApp Groupに保存し、キーボードと共有する。
final class AppModel: ObservableObject {
    let store: SettingsStore

    @Published var settings: KeyboardSettings {
        didSet {
            guard settings != oldValue else { return }
            var s = settings.normalized()
            s.updatedAt = Date()
            store.saveSharedSettings(s)
        }
    }

    @Published var userDictionary: [UserDictionaryEntry] {
        didSet {
            guard userDictionary != oldValue else { return }
            store.saveUserDictionary(userDictionary)
        }
    }

    init(store: SettingsStore = .resolved()) {
        self.store = store
        // キーボード上で変えた設定はアプリから読めないので、アプリで保存した値を表示する
        self.settings = store.loadSharedSettings() ?? .default
        self.userDictionary = store.loadUserDictionary()
        if ProcessInfo.processInfo.arguments.contains("-KeyFlowResetSettings") {
            // UIテスト用: 前のテストで変えた設定を持ち越さない（キーボードにも新しい設定として渡す）
            var s = KeyboardSettings.default
            s.updatedAt = Date()
            store.saveSharedSettings(s)
            self.settings = s
        }
    }

    var isSharedAvailable: Bool { store.isSharedAvailable }
    var appGroupIdentifier: String? { store.appGroupIdentifier }

    func resetSettings() {
        settings = .default
    }

    func requestLearningReset() {
        store.requestLearningReset()
    }

    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
