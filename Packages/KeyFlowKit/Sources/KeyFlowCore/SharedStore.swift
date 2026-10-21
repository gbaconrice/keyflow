import Foundation

/// App Group（アプリとキーボードの共有領域）のIDを見つける。
///
/// 無料のApple Accountで署名し直すツール（Sideloadly、AltStoreなど）は、
/// バンドルIDやApp Group IDを書き換えることがある。そのためビルド時のIDだけに頼らず、
/// 署名に埋め込まれたプロビジョニングプロファイルの権限情報から実際に使えるIDを探す。
public enum AppGroupResolver {
    /// Info.plistに書いたビルド時のApp Group ID
    public static let infoPlistKey = "KeyFlowAppGroup"

    public static func candidateIdentifiers(bundle: Bundle = .main) -> [String] {
        var result: [String] = []
        if let id = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String, !id.isEmpty {
            result.append(id)
        }
        if let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url) {
            result.append(contentsOf: groups(fromProvisioningProfile: data))
        }
        // AltStoreは書き換えたIDをInfo.plistのALTAppGroupsに記録する
        if let alt = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            result.append(contentsOf: alt)
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    /// プロビジョニングプロファイル（CMS署名されたplist）からApp Group IDを取り出す
    public static func groups(fromProvisioningProfile data: Data) -> [String] {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else {
            return []
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else {
            return []
        }
        return groups
    }

    /// 実際にコンテナにアクセスできるApp Group IDを返す
    public static func resolve(bundle: Bundle = .main) -> (identifier: String, containerURL: URL)? {
        #if os(iOS) || os(macOS)
        for id in candidateIdentifiers(bundle: bundle) {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return (id, url)
            }
        }
        #endif
        return nil
    }
}

/// 設定・ユーザー辞書の保存先。
///
/// - アプリはApp Groupに書き込み、キーボードはそれを読む（フルアクセスなしでは書き込めないため）
/// - キーボード上で変えた設定はキーボード自身の領域に保存し、更新時刻が新しい方を使う
/// - App Groupが使えない環境（署名の都合など）では、キーボードは自分の領域の設定だけで動く
public final class SettingsStore {
    public let appGroupIdentifier: String?
    public let sharedContainerURL: URL?
    private let shared: UserDefaults?
    private let local: UserDefaults

    private enum Key {
        static let settings = "keyflow.settings.v1"
        static let userDictionary = "keyflow.userDictionary.v1"
        static let learningResetRequest = "keyflow.learningResetRequest.v1"
        static let learningResetApplied = "keyflow.learningResetApplied.v1"
        static let localSettings = "keyflow.localSettings.v1"
    }

    public init(appGroupIdentifier: String?, sharedContainerURL: URL? = nil, local: UserDefaults = .standard) {
        self.appGroupIdentifier = appGroupIdentifier
        self.sharedContainerURL = sharedContainerURL
        self.shared = appGroupIdentifier.flatMap { UserDefaults(suiteName: $0) }
        self.local = local
    }

    /// 実行中のバンドルからApp Groupを探して初期化する
    public static func resolved(bundle: Bundle = .main) -> SettingsStore {
        let group = AppGroupResolver.resolve(bundle: bundle)
        return SettingsStore(appGroupIdentifier: group?.identifier, sharedContainerURL: group?.containerURL)
    }

    public var isSharedAvailable: Bool { shared != nil && sharedContainerURL != nil }

    // MARK: 設定

    private func decodeSettings(_ data: Data?) -> KeyboardSettings? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(KeyboardSettings.self, from: data)
    }

    /// アプリで保存した設定（App Group）
    public func loadSharedSettings() -> KeyboardSettings? {
        decodeSettings(shared?.data(forKey: Key.settings))
    }

    /// キーボード上で変更した設定
    public func loadLocalSettings() -> KeyboardSettings? {
        decodeSettings(local.data(forKey: Key.localSettings))
    }

    /// キーボードが使う設定。アプリとキーボード上の変更のうち新しい方。
    public func loadEffectiveSettings() -> KeyboardSettings {
        let candidates = [loadSharedSettings(), loadLocalSettings()].compactMap { $0 }
        let newest = candidates.max { $0.updatedAt < $1.updatedAt }
        return (newest ?? .default).normalized()
    }

    /// アプリから保存する
    public func saveSharedSettings(_ settings: KeyboardSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        shared?.set(data, forKey: Key.settings)
    }

    /// キーボード上の変更を保存する
    public func saveLocalSettings(_ settings: KeyboardSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        local.set(data, forKey: Key.localSettings)
    }

    // MARK: ユーザー辞書

    public func loadUserDictionary() -> [UserDictionaryEntry] {
        guard let data = shared?.data(forKey: Key.userDictionary) ?? local.data(forKey: Key.userDictionary) else {
            return []
        }
        return (try? JSONDecoder().decode([UserDictionaryEntry].self, from: data)) ?? []
    }

    public func saveUserDictionary(_ entries: [UserDictionaryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        if let shared {
            shared.set(data, forKey: Key.userDictionary)
        } else {
            local.set(data, forKey: Key.userDictionary)
        }
    }

    // MARK: 学習のリセット

    /// アプリから学習データの消去を依頼する（学習データはキーボード側にあるため、次にキーボードを開いたときに消える）
    public func requestLearningReset(at date: Date = Date()) {
        shared?.set(date, forKey: Key.learningResetRequest)
    }

    public var learningResetRequestedAt: Date? {
        shared?.object(forKey: Key.learningResetRequest) as? Date
    }

    /// キーボード側: 未処理の消去依頼があればtrueを返し、処理済みとして記録する
    public func consumeLearningResetRequest() -> Bool {
        guard let requested = learningResetRequestedAt else { return false }
        let applied = local.object(forKey: Key.learningResetApplied) as? Date ?? .distantPast
        guard requested > applied else { return false }
        local.set(requested, forKey: Key.learningResetApplied)
        return true
    }
}
