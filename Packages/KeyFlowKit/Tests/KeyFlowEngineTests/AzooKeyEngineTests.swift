import Foundation
import Testing
import KeyFlowCore
@testable import KeyFlowEngine

private func makeTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("keyflow-test-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("変換エンジン", .serialized)
struct AzooKeyEngineTests {
    @Test("一般的な文を変換できる")
    func basicConversion() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let list = engine.candidates(for: "きょうはいいてんきですね", requestID: 1, options: .init())
        #expect(list.candidates.first?.text == "今日はいい天気ですね")
        #expect(list.candidates.first?.consumedCount == 12)
    }

    @Test("文節の候補は先頭の一部だけを置き換える")
    func clauseCandidatesConsumePrefix() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let list = engine.candidates(for: "きょうはいいてんき", requestID: 1, options: .init())
        let clause = list.candidates.first { $0.text == "今日は" }
        #expect(clause?.consumedCount == 4)
    }

    @Test("候補に重複がない")
    func noDuplicates() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let list = engine.candidates(for: "かんじ", requestID: 1, options: .init())
        #expect(Set(list.candidates.map(\.text)).count == list.candidates.count)
    }

    @Test("確定した候補を学習して次回から上位に出す")
    func learning() {
        let dir = makeTempDirectory()
        let engine = AzooKeyEngine(memoryDirectory: dir)
        let first = engine.candidates(for: "せいかく", requestID: 1, options: .init())
        guard let target = first.candidates.dropFirst().first(where: { !$0.isPrediction && $0.consumedCount == 4 }) else {
            Issue.record("候補が足りない: \(first.candidates.map(\.text))")
            return
        }
        engine.commit(target, of: first, remaining: "", options: .init())
        engine.flushLearning()
        let second = engine.candidates(for: "せいかく", requestID: 2, options: .init())
        #expect(second.candidates.first?.text == target.text)

        // 学習を無効にすると学習結果を使わない
        let engine2 = AzooKeyEngine(memoryDirectory: dir)
        let third = engine2.candidates(for: "せいかく", requestID: 3, options: .init(learningEnabled: false))
        #expect(third.candidates.first?.text == first.candidates.first?.text)
    }

    @Test("ユーザー辞書の語が候補に出る")
    func userDictionary() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        engine.updateUserDictionary([UserDictionaryEntry(word: "KeyFlow", reading: "きーふろー")])
        let list = engine.candidates(for: "きーふろー", requestID: 1, options: .init())
        #expect(list.candidates.prefix(3).contains { $0.text == "KeyFlow" })
    }

    @Test("確定後に次の語を予測する")
    func nextWord() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let list = engine.candidates(for: "よろしく", requestID: 1, options: .init())
        guard let c = list.candidates.first(where: { $0.consumedCount == 4 }) else {
            Issue.record("候補なし")
            return
        }
        engine.commit(c, of: list, remaining: "", options: .init())
        let next = engine.nextWordCandidates(after: c, requestID: 2, options: .init())
        #expect(!next.candidates.isEmpty)
        #expect(next.candidates.allSatisfy { $0.kind == .nextWord })
    }

    @Test("絵文字候補を無効にできる")
    func emojiToggle() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let on = engine.candidates(for: "ねこ", requestID: 1, options: .init(emojiCandidates: true))
        let off = engine.candidates(for: "ねこ", requestID: 2, options: .init(emojiCandidates: false))
        #expect(on.candidates.contains { $0.text.isEmojiOnly })
        #expect(!off.candidates.contains { $0.text.isEmojiOnly })
    }
}

@Suite("入力から確定までの通し動作", .serialized)
struct EndToEndTests {
    final class Env {
        let field = SimulatedTextField()
        let controller: InputController
        init(settings: KeyboardSettings = .default) {
            let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
            let queue = ConversionQueue(engine: engine, scheduler: ImmediateTaskScheduler())
            controller = InputController(settings: settings, conversion: queue)
            controller.document = field
        }

        /// 1文字ずつフリック入力する（濁音・小書きは「小゛゜」キーで作る）
        func type(_ text: String) {
            let layout = KeyboardLayouts.kana(showsGlobeKey: false)
            for c in text {
                if let (id, spec, dir) = locate(String(c), layout) {
                    controller.flick(keyID: id, spec: spec, direction: dir)
                    if controller.state.isToggleActive { controller.cursorRight() }
                    continue
                }
                let base = KanaModifier.baseForm(c)
                guard let (id, spec, dir) = locate(String(base), layout) else { fatalError("\(c)") }
                controller.flick(keyID: id, spec: spec, direction: dir)
                if controller.state.isToggleActive { controller.cursorRight() }
                var tries = 0
                while field.documentContextBeforeInput?.last != c, tries < 3 {
                    controller.modifier(direction: .center)
                    tries += 1
                }
            }
        }

        private func locate(_ s: String, _ layout: KeyboardLayoutSpec) -> (String, FlickKeySpec, FlickDirection)? {
            for key in layout.keys {
                guard case let .flick(spec) = key.kind else { continue }
                for (d, o) in spec.outputs where o == s { return (key.id, spec, d) }
            }
            return nil
        }
    }

    @Test("「きょうはいいてんきですね」→変換→確定")
    func convertSentence() {
        let env = Env()
        env.type("きょうはいいてんきですね")
        env.controller.space()
        env.controller.enter()
        #expect(env.field.text == "今日はいい天気ですね")
        #expect(env.field.markedText == nil)
    }

    @Test("「変換」キーは予測候補を飛ばして変換候補だけを巡回する")
    func spaceSkipsPredictions() {
        let env = Env()
        env.type("おはよ")
        let candidates = env.controller.state.candidates
        #expect(candidates.contains { $0.isPrediction })
        for _ in 0..<5 {
            env.controller.space()
            let i = env.controller.state.selectedCandidateIndex ?? 0
            #expect(!env.controller.state.candidates[i].isPrediction)
        }
    }

    @Test("長い文を文節ごとに確定していく")
    func clauseByClause() {
        let env = Env()
        env.type("あしたはやくおきる")
        let state = env.controller.state
        guard let i = state.candidates.firstIndex(where: { $0.text == "明日" }) else {
            Issue.record("明日 がない: \(state.candidates.map(\.text))")
            return
        }
        env.controller.selectCandidate(at: i, requestID: state.candidateRequestID)
        #expect(env.field.text == "明日はやくおきる")
        #expect(env.field.markedText == "はやくおきる")
        #expect(env.controller.state.isComposing)
        env.controller.space()
        env.controller.enter()
        #expect(env.field.markedText == nil || env.controller.state.isComposing)
    }

    @Test("marked textを使わない設定でも同じ文字列になる")
    func plainMode() {
        var s = KeyboardSettings()
        s.usesMarkedText = false
        let env = Env(settings: s)
        env.type("きょうはいいてんきですね")
        env.controller.space()
        env.controller.enter()
        #expect(env.field.text == "今日はいい天気ですね")
    }
}

@Suite("変換の補正")
struct ConversionHeuristicsTests {
    @Test("数字の後の「次」は、後ろに漢字が続かなければ「時」にする")
    func digitJi() {
        #expect(ConversionHeuristics.preferredVariant(of: "3次に駅前") == "3時に駅前")
        #expect(ConversionHeuristics.preferredVariant(of: "10次") == "10時")
        #expect(ConversionHeuristics.preferredVariant(of: "夜9次から") == "夜9時から")
        #expect(ConversionHeuristics.preferredVariant(of: "３次まで") == "３時まで")
    }

    @Test("「3次元」「2次会」「3時間」は変えない")
    func keepCompounds() {
        #expect(ConversionHeuristics.preferredVariant(of: "3次元") == nil)
        #expect(ConversionHeuristics.preferredVariant(of: "2次会") == nil)
        #expect(ConversionHeuristics.preferredVariant(of: "3時間") == nil)
        #expect(ConversionHeuristics.preferredVariant(of: "次に") == nil)
    }

    @Test("「第＋数字＋時＋漢字」は「次」にする")
    func daiJi() {
        #expect(ConversionHeuristics.preferredVariant(of: "第2時世界大戦") == "第2次世界大戦")
        #expect(ConversionHeuristics.preferredVariant(of: "第3次産業") == nil)
    }

    @Test("点数差が大きいとき（学習済みなど）は並べ替えない")
    func scoreGate() {
        let close = [("3次に", Float(-10.0)), ("3時に", Float(-10.5))]
        #expect(ConversionHeuristics.reorder(close, text: { $0.0 }, score: { $0.1 }).first?.0 == "3時に")
        let far = [("3次に", Float(-10.0)), ("3時に", Float(-12.0))]
        #expect(ConversionHeuristics.reorder(far, text: { $0.0 }, score: { $0.1 }).first?.0 == "3次に")
    }

    @Test("実際の変換で直る")
    func endToEnd() {
        let engine = AzooKeyEngine(memoryDirectory: makeTempDirectory())
        let cases = [
            ("3じにえきまえ", "3時に駅前"),
            ("よる9じから", "夜9時から"),
            ("12じ", "12時"),
            ("3じげん", "3次元"),
            ("2じかい", "2次会"),
            ("だい2じせかいたいせん", "第2次世界大戦"),
            ("2じのほうていしき", "2次の方程式"),
            ("12じまでまってる", "12時まで待ってる"),
            ("ごご3じにしゅうごう", "午後3時に集合"),
        ]
        for (i, (reading, expected)) in cases.enumerated() {
            let list = engine.candidates(for: reading, requestID: i, options: .init(predictionEnabled: false))
            #expect(list.candidates.first?.text == expected, "\(reading)")
        }
    }
}
