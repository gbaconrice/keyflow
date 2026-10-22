import Foundation
import Testing
@testable import KeyFlowCore

@Suite("ローマ字の変換")
struct RomajiConverterTests {
    @Test("綴りをかなにする", arguments: [
        ("kyouhaiitenki", "きょうはいいてんき"),
        ("konnnichiha", "こんにちは"),
        ("kitte", "きって"),
        ("shinbunshi", "しんぶんし"),
        ("kanji", "かんじ"),
        ("nya", "にゃ"),
        ("xtu", "っ"),
        ("tsu", "つ"),
        ("fa", "ふぁ"),
        ("chotto", "ちょっと"),
        ("honnyaku", "ほんやく"),
        ("gennann", "げんあん"),
        ("ja", "じゃ"),
        ("dhi", "でぃ"),
        ("wo", "を"),
    ])
    func converts(input: String, expected: String) {
        #expect(RomajiConverter.convert(input) == expected)
    }

    @Test("綴りの途中は英字のまま残す")
    func pending() {
        #expect(RomajiConverter.convert("k") == "k")
        #expect(RomajiConverter.convert("ky") == "ky")
        #expect(RomajiConverter.convert("kan") == "かn")
        #expect(RomajiConverter.convert("kk") == "っk")
        #expect(RomajiConverter.convert("ts") == "ts")
    }

    @Test("区切りでは末尾のnを「ん」にし、それ以外は英字のまま確定する")
    func flush() {
        #expect(RomajiConverter.flush("n") == "ん")
        #expect(RomajiConverter.flush("kan") == "かん")
        #expect(RomajiConverter.flush("k") == "k")
        #expect(RomajiConverter.flush("ny") == "んy")
        #expect(RomajiConverter.flush("ts") == "ts")
    }
}

@Suite("ローマ字入力")
struct RomajiInputTests {
    private func harness(text: String = "") -> Harness {
        var settings = KeyboardSettings.default
        settings.kanaLayout = .romaji
        return Harness(settings: settings, text: text)
    }

    private func type(_ h: Harness, _ letters: String) {
        for c in letters {
            h.controller.character(String(c))
        }
    }

    @Test("ローマ字で打った文字がかなの入力中の文字列になり、変換・確定できる")
    func typeAndConvert() {
        let h = harness()
        type(h, "kyouh")
        #expect(h.field.markedText == "きょうh")
        // 綴りの途中の英字は除いて変換する
        #expect(h.candidates.first == "今日")
        type(h, "a")
        #expect(h.field.markedText == "きょうは")
        #expect(h.candidates.first == "今日は")
        h.controller.space()
        h.controller.enter()
        #expect(h.field.text == "今日は")
    }

    @Test("末尾のnは変換・確定のときに「ん」になる")
    func trailingN() {
        let h = harness()
        type(h, "kan")
        #expect(h.field.markedText == "かn")
        type(h, "ji")
        #expect(h.field.markedText == "かんじ")
        h.controller.enter()
        #expect(h.field.text == "かんじ")

        let h2 = harness()
        type(h2, "kan")
        h2.controller.enter()
        #expect(h2.field.text == "かん")
    }

    @Test("「ー」や句読点の前のnは「ん」になる")
    func nBeforeSymbol() {
        let h = harness()
        type(h, "un")
        h.controller.character("ー")
        #expect(h.field.markedText == "うんー")
        let comma = KeyboardLayouts.romaji(showsGlobeKey: false).keys.first { $0.id == "ro_comma" }!
        guard case let .flick(spec) = comma.kind else { Issue.record("not a flick key"); return }
        type(h, "n")
        h.controller.flick(keyID: "ro_comma", spec: spec, direction: .center)
        #expect(h.field.markedText == "うんーん、")
        h.controller.flick(keyID: "ro_comma", spec: spec, direction: .up)
        #expect(h.field.markedText == "うんーん、？")
    }

    @Test("削除は1文字ずつ（英字・かなとも）消す")
    func delete() {
        let h = harness()
        type(h, "kak")
        #expect(h.field.markedText == "かk")
        h.controller.delete()
        #expect(h.field.markedText == "か")
        h.controller.delete()
        #expect(h.field.markedText == nil)
        #expect(h.field.text == "")
    }

    @Test("シフト中の文字は大文字の英字のまま入る")
    func shiftLetter() {
        let h = harness()
        h.controller.toggleShift()
        type(h, "a")
        type(h, "a")
        #expect(h.field.markedText == "Aあ")
    }

    @Test("候補が読みの一部だけを使うとき、残りの綴りはそのまま続けられる")
    func partialCommit() {
        let h = harness()
        type(h, "kyoun")
        // 「きょうん」全体の候補は無く、先頭の「きょう」の候補だけが出る
        let index = h.candidates.firstIndex(of: "今日")!
        h.controller.selectCandidate(at: index, requestID: h.controller.state.candidateRequestID)
        #expect(h.field.text == "今日n")
        #expect(h.field.markedText == "n")
        type(h, "i")
        #expect(h.field.markedText == "に")
    }

    @Test("英字に切り替えると、綴りの途中のnも「ん」にして確定する")
    func switchToEnglish() {
        let h = harness()
        type(h, "kan")
        h.controller.switchMode(to: .english)
        #expect(h.field.text == "かん")
        #expect(h.field.markedText == nil)
        h.controller.character("a")
        #expect(h.field.text == "かんa")
    }

    @Test("入力中にカーソルを動かすと、綴りの途中のnを「ん」にしてから動かす")
    func moveCursor() {
        let h = harness()
        type(h, "kan")
        h.controller.moveCursor(by: -1)
        #expect(h.field.markedText == "かん")
        #expect(h.field.cursor == 1)
        type(h, "ka")
        #expect(h.field.markedText == "かかん")
    }

    @Test("QWERTYの数字配列の文字も入力中の文字列に入り、続けて変換できる")
    func qwertyNumbers() {
        let h = harness()
        #expect(KeyboardLayouts.layout(for: .number, showsGlobeKey: false, kanaLayout: .romaji).isRowBased)
        type(h, "n")
        h.controller.switchMode(to: .number)
        h.controller.character("3")
        #expect(h.field.markedText == "ん3")
        h.controller.switchMode(to: .kana)
        type(h, "ji")
        #expect(h.field.markedText == "ん3じ")
        h.controller.enter()
        #expect(h.field.text == "ん3じ")
    }

    @Test("marked textを使わない設定でも同じ結果になる")
    func plainText() {
        var settings = KeyboardSettings.default
        settings.kanaLayout = .romaji
        settings.usesMarkedText = false
        let h = Harness(settings: settings)
        for c in "kyoun" {
            h.controller.character(String(c))
        }
        #expect(h.field.text == "きょうn")
        h.controller.enter()
        #expect(h.field.text == "きょうん")
    }
}
