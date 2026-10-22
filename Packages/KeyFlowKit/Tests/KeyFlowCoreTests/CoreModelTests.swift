import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import KeyFlowCore

@Suite("フリック判定")
struct FlickClassifierTests {
    @Test("しきい値未満はタップ")
    func tap() {
        let c = FlickClassifier(threshold: 20)
        #expect(c.direction(dx: 5, dy: 10) == .center)
        #expect(c.direction(dx: 14, dy: 14) == .center)
    }

    @Test("4方向")
    func directions() {
        let c = FlickClassifier(threshold: 20)
        #expect(c.direction(dx: -30, dy: 2) == .left)
        #expect(c.direction(dx: 30, dy: -2) == .right)
        #expect(c.direction(dx: 3, dy: -30) == .up)
        #expect(c.direction(dx: -3, dy: 30) == .down)
    }

    @Test("斜めの入力は上下を少し優先する")
    func diagonalBias() {
        let c = FlickClassifier(threshold: 20, verticalBias: 1.15)
        // 45°ちょうどなら上
        #expect(c.direction(dx: 25, dy: -25) == .up)
        // 横の方が明らかに大きければ右
        #expect(c.direction(dx: 30, dy: -24) == .right)
    }
}

@Suite("濁点・小文字")
struct KanaModifierTests {
    @Test("巡回")
    func cycle() {
        #expect(KanaModifier.cycle("か") == "が")
        #expect(KanaModifier.cycle("が") == "か")
        #expect(KanaModifier.cycle("は") == "ば")
        #expect(KanaModifier.cycle("ば") == "ぱ")
        #expect(KanaModifier.cycle("ぱ") == "は")
        #expect(KanaModifier.cycle("つ") == "っ")
        #expect(KanaModifier.cycle("っ") == "づ")
        #expect(KanaModifier.cycle("づ") == "つ")
        #expect(KanaModifier.cycle("う") == "ぅ")
        #expect(KanaModifier.cycle("ぅ") == "ゔ")
        #expect(KanaModifier.cycle("ゔ") == "う")
        #expect(KanaModifier.cycle("や") == "ゃ")
        #expect(KanaModifier.cycle("ん") == nil)
        #expect(KanaModifier.cycle("漢") == nil)
    }

    @Test("カタカナにも効く")
    func katakana() {
        #expect(KanaModifier.cycle("カ") == "ガ")
        #expect(KanaModifier.cycle("ツ") == "ッ")
        #expect(KanaModifier.toggle(.handakuten, on: "ハ") == "パ")
    }

    @Test("指定した修飾の付け外し")
    func toggle() {
        #expect(KanaModifier.toggle(.dakuten, on: "さ") == "ざ")
        #expect(KanaModifier.toggle(.dakuten, on: "ざ") == "さ")
        #expect(KanaModifier.toggle(.small, on: "よ") == "ょ")
        #expect(KanaModifier.toggle(.handakuten, on: "か") == nil)
        #expect(KanaModifier.toggle(.dakuten, on: "ぱ") == "ば")
    }
}

@Suite("レイアウト計算")
struct LayoutEngineTests {
    let width = 393.0

    @Test("12キーは5列4行に収まり、キーが重ならない")
    func kanaLayoutFits() {
        let spec = KeyboardLayouts.kana(showsGlobeKey: false)
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: .default))
        #expect(g.keys.count == spec.keys.count)
        for a in g.keys {
            #expect(a.frame.minX >= 0 && a.frame.maxX <= width)
            #expect(a.frame.minY >= 0 && a.frame.maxY <= g.size.height)
            for b in g.keys where a.definition.id != b.definition.id {
                #expect(!a.frame.intersects(b.frame), "\(a.definition.id) と \(b.definition.id) が重なっている")
            }
        }
    }

    @Test("すべての配列で、キーが重ならず幅に収まる", arguments: [
        KeyboardLayouts.kana(showsGlobeKey: true),
        KeyboardLayouts.number(showsGlobeKey: false),
        KeyboardLayouts.number(showsGlobeKey: true),
        KeyboardLayouts.englishFlick(showsGlobeKey: false),
        KeyboardLayouts.englishFlick(showsGlobeKey: true),
        KeyboardLayouts.english(showsGlobeKey: false),
    ])
    func allLayoutsFit(spec: KeyboardLayoutSpec) {
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: .default))
        let ids = spec.keys.map(\.id)
        #expect(Set(ids).count == ids.count, "キーIDが重複している")
        for a in g.keys {
            #expect(a.frame.minX >= 0 && a.frame.maxX <= width + 0.5)
            for b in g.keys where a.definition.id != b.definition.id {
                #expect(!a.frame.intersects(b.frame), "\(a.definition.id) と \(b.definition.id) が重なっている")
            }
        }
    }

    @Test("キー間の隙間に触れても最寄りのキーが反応する")
    func gapsAreCovered() {
        let spec = KeyboardLayouts.kana(showsGlobeKey: false)
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: .default))
        var y = 1.0
        while y < g.size.height - 1 {
            var x = 1.0
            while x < width - 1 {
                #expect(g.key(at: CGPoint(x: x, y: y)) != nil, "(\(x), \(y)) にキーがない")
                x += 3
            }
            y += 3
        }
    }

    @Test("改行キーは2行分の高さ")
    func enterSpansTwoRows() {
        let spec = KeyboardLayouts.kana(showsGlobeKey: false)
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: .default))
        let enter = g.keys.first { $0.definition.id == "enter" }!
        let space = g.keys.first { $0.definition.id == "space" }!
        #expect(enter.frame.height > space.frame.height * 1.9)
    }

    @Test("片手モードでは指定した側に寄せる")
    func oneHanded() {
        var s = KeyboardSettings()
        s.oneHandedMode = .right
        s.oneHandedWidthRatio = 0.8
        let spec = KeyboardLayouts.kana(showsGlobeKey: false)
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: s))
        let minX = g.keys.map(\.frame.minX).min()!
        #expect(minX > width * 0.19)
        // 空いた側をタップしてもキーは反応しない
        #expect(g.key(at: CGPoint(x: 10, y: 100)) == nil)
    }

    @Test("QWERTYは各行が幅に収まる")
    func qwerty() {
        let spec = KeyboardLayouts.english(showsGlobeKey: true)
        let g = LayoutEngine.layout(spec, context: .init(width: width, isLandscape: false, settings: .default))
        for k in g.keys {
            #expect(k.frame.maxX <= width + 0.5, "\(k.definition.id) がはみ出している")
        }
        let space = g.keys.first { $0.definition.id == "space" }!
        #expect(space.frame.width > 100)
    }

    @Test("横画面では中央に寄せて幅を絞る")
    func landscape() {
        var s = KeyboardSettings()
        s.landscapeWidthRatio = 0.7
        let w = 852.0
        let spec = KeyboardLayouts.kana(showsGlobeKey: false)
        let g = LayoutEngine.layout(spec, context: .init(width: w, isLandscape: true, settings: s))
        let minX = g.keys.map(\.frame.minX).min()!
        let maxX = g.keys.map(\.frame.maxX).max()!
        #expect(abs((minX + maxX) / 2 - w / 2) < 1)
        #expect(maxX - minX < w * 0.71)
    }
}

@Suite("設定")
struct SettingsTests {
    @Test("古い形式（キーが欠けている）でも既定値で補って読める")
    func decodeWithMissingKeys() throws {
        let json = #"{"flickThreshold": 30, "unknownKey": 1}"#
        let s = try JSONDecoder().decode(KeyboardSettings.self, from: Data(json.utf8))
        #expect(s.flickThreshold == 30)
        #expect(s.portraitKeyAreaHeight == KeyboardSettings.default.portraitKeyAreaHeight)
    }

    @Test("範囲外の値は丸める")
    func normalize() {
        var s = KeyboardSettings()
        s.portraitKeyAreaHeight = 9999
        s.flickThreshold = -5
        let n = s.normalized()
        #expect(n.portraitKeyAreaHeight == KeyboardSettings.Ranges.portraitKeyAreaHeight.upperBound)
        #expect(n.flickThreshold == KeyboardSettings.Ranges.flickThreshold.lowerBound)
    }

    @Test("往復しても値が変わらない")
    func roundTrip() throws {
        var s = KeyboardSettings()
        s.oneHandedMode = .left
        s.spaceWidth = .full
        s.updatedAt = Date(timeIntervalSince1970: 12345)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(KeyboardSettings.self, from: data)
        #expect(back == s)
    }
}

@Suite("共有ストア")
struct SharedStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "keyflow-test-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test("アプリの設定とキーボード上の変更のうち新しい方を使う")
    func newestWins() {
        let groupName = "keyflow-test-group-\(UUID().uuidString)"
        let local = makeDefaults()
        let store = SettingsStore(appGroupIdentifier: groupName, local: local)
        var app = KeyboardSettings()
        app.flickThreshold = 30
        app.updatedAt = Date(timeIntervalSince1970: 100)
        store.saveSharedSettings(app)
        #expect(store.loadEffectiveSettings().flickThreshold == 30)

        var keyboard = KeyboardSettings()
        keyboard.flickThreshold = 15
        keyboard.updatedAt = Date(timeIntervalSince1970: 200)
        store.saveLocalSettings(keyboard)
        #expect(store.loadEffectiveSettings().flickThreshold == 15)

        app.flickThreshold = 25
        app.updatedAt = Date(timeIntervalSince1970: 300)
        store.saveSharedSettings(app)
        #expect(store.loadEffectiveSettings().flickThreshold == 25)
    }

    @Test("App Groupが無くても既定値で動く")
    func noAppGroup() {
        let store = SettingsStore(appGroupIdentifier: nil, local: makeDefaults())
        #expect(store.loadEffectiveSettings() == KeyboardSettings.default.normalized())
        store.saveUserDictionary([UserDictionaryEntry(word: "鍵流", reading: "きーふろー")])
        #expect(store.loadUserDictionary().count == 1)
    }

    @Test("学習リセットの依頼は1回だけ処理される")
    func learningReset() {
        let store = SettingsStore(appGroupIdentifier: "keyflow-test-group-\(UUID().uuidString)", local: makeDefaults())
        #expect(!store.consumeLearningResetRequest())
        store.requestLearningReset(at: Date(timeIntervalSince1970: 1000))
        #expect(store.consumeLearningResetRequest())
        #expect(!store.consumeLearningResetRequest())
        store.requestLearningReset(at: Date(timeIntervalSince1970: 2000))
        #expect(store.consumeLearningResetRequest())
    }

    @Test("プロビジョニングプロファイルからApp Group IDを取り出す")
    func provisioningProfile() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Entitlements</key><dict>
        <key>com.apple.security.application-groups</key><array><string>group.jp.keyflow.ime.ABCDE12345</string></array>
        </dict></dict></plist>
        """
        // 実際のファイルはCMS署名でバイナリに包まれているので、前後にゴミを付けて再現する
        var data = Data([0x30, 0x82, 0x01, 0x00, 0xFF])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0, 0x82]))
        #expect(AppGroupResolver.groups(fromProvisioningProfile: data) == ["group.jp.keyflow.ime.ABCDE12345"])
        #expect(AppGroupResolver.groups(fromProvisioningProfile: Data([1, 2, 3])).isEmpty)
    }
}
