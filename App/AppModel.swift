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
