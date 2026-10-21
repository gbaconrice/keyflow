import Foundation
@testable import KeyFlowCore

/// 辞書を引く簡易エンジン。入力の先頭から最長一致した語を候補にする。
final class MockEngine: ConversionEngine {
    var dictionary: [String: [String]] = [
        "きょう": ["今日", "京"],
        "きょうは": ["今日は"],
        "いい": ["良い"],
        "てんき": ["天気", "転機"],
        "きょうはいいてんき": ["今日はいい天気"],
        "かんじ": ["漢字", "感じ"],
    ]
    var nextWords: [String: [String]] = ["今日": ["は", "も"]]
    private(set) var committed: [String] = []
    private(set) var resetCount = 0

    func candidates(for source: String, requestID: Int, options: ConversionOptions) -> CandidateList {
        var result: [ConversionCandidate] = []
        // 全体一致
        for w in dictionary[source] ?? [] {
            result.append(.init(text: w, consumedCount: source.count, engineIndex: result.count))
        }
        // 先頭からの部分一致（文節）
        let chars = Array(source)
        for length in stride(from: chars.count - 1, through: 1, by: -1) {
            let prefix = String(chars[0..<length])
            for w in dictionary[prefix] ?? [] {
                result.append(.init(text: w, consumedCount: length, engineIndex: result.count))
            }
        }
        result.append(.init(text: source, consumedCount: source.count, engineIndex: result.count))
        return CandidateList(requestID: requestID, source: source, candidates: result)
    }

    func commit(_ candidate: ConversionCandidate, of list: CandidateList, remaining: String, options: ConversionOptions) {
        committed.append(candidate.text)
    }

    func nextWordCandidates(after committed: ConversionCandidate, requestID: Int, options: ConversionOptions) -> CandidateList {
        let words = nextWords[committed.text] ?? []
        return CandidateList(requestID: requestID, source: "", candidates: words.enumerated().map {
            .init(text: $1, consumedCount: 0, kind: .nextWord, engineIndex: $0)
        })
    }

    func resetComposition() { resetCount += 1 }
    func flushLearning() {}
    func resetLearning() {}
    func updateUserDictionary(_ entries: [UserDictionaryEntry]) {}
}

/// テスト用の時計
final class TestClock {
    var current = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

/// キー配列から定義を引くヘルパー
struct Keys {
    static let kana = KeyboardLayouts.kana(showsGlobeKey: false)
    static let number = KeyboardLayouts.number(showsGlobeKey: false)

    static func spec(_ id: String, in layout: KeyboardLayoutSpec = kana) -> FlickKeySpec {
        guard let key = layout.keys.first(where: { $0.id == id }), case let .flick(spec) = key.kind else {
            fatalError("no flick key \(id)")
        }
        return spec
    }

    /// ひらがな1文字を入力するためのキーと方向
    static func locate(_ char: String) -> (id: String, spec: FlickKeySpec, direction: FlickDirection)? {
        for key in kana.keys {
            guard case let .flick(spec) = key.kind else { continue }
            for (direction, out) in spec.outputs where out == char {
                return (key.id, spec, direction)
            }
        }
        return nil
    }
}

/// InputControllerとSimulatedTextFieldを組み合わせたテスト環境
final class Harness {
    let field: SimulatedTextField
    let engine = MockEngine()
    let clock = TestClock()
    let controller: InputController

    init(settings: KeyboardSettings = .default, text: String = "") {
        field = SimulatedTextField(text: text)
        let queue = ConversionQueue(engine: engine, scheduler: ImmediateTaskScheduler())
        let clock = self.clock
        controller = InputController(settings: settings, conversion: queue, now: { clock.current })
        controller.document = field
    }

    /// ひらがなをフリック（トグルを避けるため、中央タップの後は▶で区切る）。
    /// 濁音・小書きは清音を入力してから「小゛゜」キーで変える。
    func flick(_ text: String) {
        for c in text {
            if let k = Keys.locate(String(c)) {
                press(k)
                continue
            }
            let base = KanaModifier.baseForm(c)
            guard let k = Keys.locate(String(base)) else { fatalError("cannot type \(c)") }
            press(k)
            var tries = 0
            while field.documentContextBeforeInput?.last != c, tries < 3 {
                controller.modifier(direction: .center)
                tries += 1
            }
        }
    }

    private func press(_ k: (id: String, spec: FlickKeySpec, direction: FlickDirection)) {
        controller.flick(keyID: k.id, spec: k.spec, direction: k.direction)
        clock.advance(0.1)
        if k.direction == .center {
            controller.cursorRight()
        }
    }

    func tap(_ id: String, times: Int = 1) {
        let spec = Keys.spec(id)
        for _ in 0..<times {
            controller.flick(keyID: id, spec: spec, direction: .center)
            clock.advance(0.1)
        }
    }

    var candidates: [String] { controller.state.candidates.map(\.text) }
}
