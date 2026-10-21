import Foundation
import Testing
@testable import KeyFlowCore

@Suite("入力状態管理")
struct InputControllerTests {
    @Test("フリックで入力した文字がmarked textとして表示される")
    func flickShowsMarkedText() {
        let h = Harness()
        h.flick("きょう")
        #expect(h.field.text == "きょう")
        #expect(h.field.markedText == "きょう")
        #expect(h.controller.state.isComposing)
        #expect(h.candidates.first == "今日")
    }

    @Test("トグル入力: 同じキーの連打で文字が巡回する")
    func toggleCycles() {
        let h = Harness()
        h.tap("a", times: 3)
        #expect(h.field.text == "う")
        h.tap("a", times: 3)
        #expect(h.field.text == "ぁ")
    }

    @Test("▶でトグルを区切ると同じ文字を続けて入力できる")
    func cursorRightSplitsToggle() {
        let h = Harness()
        h.tap("a")
        h.controller.cursorRight()
        h.tap("a")
        #expect(h.field.text == "ああ")
    }

    @Test("◀でトグルを1つ戻す")
    func cursorLeftReversesToggle() {
        let h = Harness()
        h.tap("ka", times: 3)
        #expect(h.field.text == "く")
        h.controller.cursorLeft()
        #expect(h.field.text == "き")
    }

    @Test("トグル入力を無効にすると連打で同じ文字が続く")
    func toggleDisabled() {
        var s = KeyboardSettings()
        s.toggleInputEnabled = false
        let h = Harness(settings: s)
        h.tap("a", times: 3)
        #expect(h.field.text == "あああ")
    }

    @Test("トグルの確定時間を過ぎると新しい文字になる")
    func toggleTimeout() {
        var s = KeyboardSettings()
        s.toggleTimeout = 0.5
        let h = Harness(settings: s)
        h.tap("a")
        h.clock.advance(1.0)
        h.tap("a")
        #expect(h.field.text == "ああ")
    }

    @Test("小゛゜キーで濁点・小文字を巡回する")
    func modifierCycle() {
        let h = Harness()
        h.flick("つ")
        h.controller.modifier(direction: .center)
        #expect(h.field.text == "っ")
        h.controller.modifier(direction: .center)
        #expect(h.field.text == "づ")
        h.controller.modifier(direction: .center)
        #expect(h.field.text == "つ")
        h.flick("は")
        h.controller.modifier(direction: .center)
        h.controller.modifier(direction: .center)
        #expect(h.field.text == "つぱ")
    }

    @Test("小゛゜キーのフリックで濁点・半濁点・小文字を直接指定する")
    func modifierFlick() {
        let h = Harness()
        h.flick("は")
        h.controller.modifier(direction: .right)
        #expect(h.field.text == "ぱ")
        h.controller.modifier(direction: .left)
        #expect(h.field.text == "ば")
        h.controller.modifier(direction: .left)
        #expect(h.field.text == "は")
    }

    @Test("変換→次候補→確定")
    func convertAndCommit() {
        let h = Harness()
        h.flick("かんじ")
        #expect(h.controller.state.spaceKeyLabel == "変換")
        h.controller.space()
        #expect(h.field.markedText == "漢字")
        #expect(h.controller.state.selectedCandidateIndex == 0)
        h.controller.space()
        #expect(h.field.markedText == "感じ")
        h.controller.enter()
        #expect(h.field.text == "感じ")
        #expect(h.field.markedText == nil)
        #expect(!h.controller.state.isComposing)
        #expect(h.engine.committed == ["感じ"])
    }

    @Test("候補をタップして確定")
    func tapCandidate() {
        let h = Harness(text: "こんにちは。")
        h.flick("きょう")
        let state = h.controller.state
        h.controller.selectCandidate(at: 0, requestID: state.candidateRequestID)
        #expect(h.field.text == "こんにちは。今日")
        #expect(h.field.cursor == h.field.text.count)
    }

    @Test("文節の候補を確定すると残りが入力中のまま続く")
    func partialCommit() {
        let h = Harness()
        h.flick("きょうはいいてんき")
        let state = h.controller.state
        guard let index = state.candidates.firstIndex(where: { $0.text == "今日は" }) else {
            Issue.record("今日は が候補にない: \(h.candidates)")
            return
        }
        h.controller.selectCandidate(at: index, requestID: state.candidateRequestID)
        #expect(h.field.text == "今日はいいてんき")
        #expect(h.field.markedText == "いいてんき")
        #expect(h.controller.state.isComposing)
        #expect(h.candidates.first == "良い")
    }

    @Test("候補選択中に次の文字を入力すると選択中の候補が確定される")
    func typingAfterSelectionCommits() {
        let h = Harness()
        h.flick("きょう")
        h.controller.space()
        h.flick("は")
        #expect(h.field.text == "今日は")
        #expect(h.field.markedText == "は")
    }

    @Test("候補選択中の削除は読みに戻す")
    func deleteDuringSelectionRevertsToReading() {
        let h = Harness()
        h.flick("きょう")
        h.controller.space()
        #expect(h.field.markedText == "今日")
        h.controller.delete()
        #expect(h.field.markedText == "きょう")
        #expect(h.controller.state.selectedCandidateIndex == nil)
    }

    @Test("入力中の削除は1文字ずつ消し、空になれば入力を終える")
    func deleteWhileComposing() {
        let h = Harness(text: "abc")
        h.flick("あい")
        h.controller.delete()
        #expect(h.field.text == "abcあ")
        h.controller.delete()
        #expect(h.field.text == "abc")
        #expect(!h.controller.state.isComposing)
        h.controller.delete()
        #expect(h.field.text == "ab")
    }

    @Test("改行キーは入力中ならそのまま確定、入力中でなければ改行")
    func enterKey() {
        let h = Harness()
        h.flick("あい")
        #expect(h.controller.state.enterKeyLabel == "確定")
        h.controller.enter()
        #expect(h.field.text == "あい")
        #expect(h.field.markedText == nil)
        h.controller.enter()
        #expect(h.field.text == "あい\n")
    }

    @Test("確定後に「取消」で読みに戻して選び直せる")
    func undoCommit() {
        let h = Harness(text: "x")
        h.flick("かんじ")
        h.controller.space()
        h.controller.enter()
        #expect(h.field.text == "x漢字")
        #expect(h.controller.state.canUndoCommit)
        h.controller.undoLastCommit()
        #expect(h.field.text == "xかんじ")
        #expect(h.field.markedText == "かんじ")
        h.controller.space()
        h.controller.space()
        h.controller.enter()
        #expect(h.field.text == "x感じ")
    }

    @Test("確定後に次の語の予測が出て、タップで入力できる")
    func nextWordPrediction() {
        let h = Harness()
        h.flick("きょう")
        h.controller.space()
        h.controller.enter()
        #expect(h.candidates == ["は", "も"])
        h.controller.selectCandidate(at: 0, requestID: h.controller.state.candidateRequestID)
        #expect(h.field.text == "今日は")
    }

    @Test("入力中に◀でカーソルを動かすと、カーソルより前だけを変換する")
    func cursorInsideComposition() {
        let h = Harness()
        h.flick("きょうは")
        h.controller.cursorLeft()
        #expect(h.field.cursor == 3)
        #expect(h.candidates.first == "今日")
        h.controller.space()
        #expect(h.field.markedText == "今日は")
        h.controller.enter()
        #expect(h.field.text == "今日は")
        // 残った「は」が入力中のまま続く
        #expect(h.field.markedText == "は")
        h.controller.enter()
        #expect(h.field.markedText == nil)
    }

    @Test("入力中でないときの◀▶は入力欄のカーソルを動かす")
    func cursorMovesDocument() {
        let h = Harness(text: "あいう")
        h.controller.cursorLeft()
        #expect(h.field.cursor == 2)
        h.controller.cursorRight()
        #expect(h.field.cursor == 3)
    }

    @Test("絵文字をまたぐカーソル移動はUTF-16単位で動かす")
    func cursorOverEmoji() {
        let h = Harness(text: "a👍🏻b")
        h.controller.cursorLeft()
        h.controller.cursorLeft()
        #expect(h.field.cursor == 1)
    }

    @Test("ユーザーが入力欄をタップした後は入力中の状態を捨て、文字を重複させない")
    func externalCursorMoveAbandonsComposition() {
        let h = Harness(text: "abc")
        h.flick("きょう")
        h.clock.advance(1.0)
        // ユーザーが先頭をタップ（ホスト側でmarked textが確定される）
        h.field.simulateUserTap(at: 0)
        h.controller.documentDidChange()
        #expect(!h.controller.state.isComposing)
        h.flick("あ")
        #expect(h.field.text == "あabcきょう")
    }

    @Test("通知が届かないまま外部でカーソルが動いても、次のキー入力で検出する")
    func externalChangeDetectedOnNextKey() {
        let h = Harness(text: "abc")
        h.flick("きょう")
        h.clock.advance(1.0)
        h.field.simulateUserTap(at: 1)
        h.flick("あ")
        #expect(h.field.text == "aあbcきょう")
    }

    @Test("自分の操作による通知では入力中の状態を保つ")
    func ownEditNotificationKeepsComposition() {
        let h = Harness()
        h.flick("きょう")
        h.controller.documentDidChange()
        #expect(h.controller.state.isComposing)
        h.flick("は")
        #expect(h.field.markedText == "きょうは")
    }

    @Test("英字モードでは直接入力し、シフトは1文字だけ大文字にする")
    func englishInput() {
        let h = Harness()
        h.flick("あ")
        h.controller.switchMode(to: .english)
        #expect(h.field.text == "あ")
        #expect(h.field.markedText == nil)
        h.controller.toggleShift()
        h.controller.character("h")
        h.controller.character("i")
        h.controller.space()
        #expect(h.field.text == "あHi ")
        #expect(h.controller.state.spaceKeyLabel == "space")
    }

    @Test("シフトの2回タップで大文字固定")
    func capsLock() {
        let h = Harness()
        h.controller.switchMode(to: .english)
        h.controller.toggleShift()
        h.clock.advance(0.1)
        h.controller.toggleShift()
        #expect(h.controller.state.shift == .locked)
        h.controller.character("a")
        h.controller.character("b")
        #expect(h.field.text == "AB")
    }

    @Test("数字モードの入力も変換対象になる")
    func numberModeComposes() {
        let h = Harness()
        h.controller.switchMode(to: .number)
        let spec = Keys.spec("n1", in: Keys.number)
        h.controller.flick(keyID: "n1", spec: spec, direction: .center)
        #expect(h.field.markedText == "1")
        h.controller.flick(keyID: "n1", spec: spec, direction: .center)
        #expect(h.field.markedText == "☆")
    }

    @Test("marked textを使わない設定でも同じ結果になる")
    func plainTextMode() {
        var s = KeyboardSettings()
        s.usesMarkedText = false
        let h = Harness(settings: s, text: "x")
        h.flick("かんじ")
        #expect(h.field.text == "xかんじ")
        #expect(h.field.markedText == nil)
        h.controller.space()
        #expect(h.field.text == "x漢字")
        h.controller.space()
        #expect(h.field.text == "x感じ")
        h.controller.enter()
        #expect(h.field.text == "x感じ")
        h.flick("きょう")
        h.controller.delete()
        #expect(h.field.text == "x感じきょ")
        h.controller.enter()
        #expect(h.field.text == "x感じきょ")
        #expect(!h.controller.state.isComposing)
    }

    @Test("空白キーは入力中でなければ設定に応じた空白を入れる")
    func spaceWidth() {
        var s = KeyboardSettings()
        s.spaceWidth = .full
        let h = Harness(settings: s)
        h.controller.space()
        #expect(h.field.text == "　")
    }

    @Test("確定済みの直前の文字にも濁点を付けられる")
    func modifierOnCommittedText() {
        let h = Harness(text: "か")
        h.controller.modifier(direction: .center)
        #expect(h.field.text == "が")
    }

    @Test("URL欄では英字モードで始まる")
    func urlFieldStartsInEnglish() {
        let h = Harness()
        h.controller.configure(returnKey: .go, enablesReturnKeyAutomatically: false, fieldKind: .url)
        #expect(h.controller.state.mode == .english)
        #expect(h.controller.state.enterKeyLabel == "go")
    }

    @Test("入力欄が空のとき改行キーを無効にする設定に従う")
    func enterKeyDisabledWhenEmpty() {
        let h = Harness()
        h.controller.configure(returnKey: .search, enablesReturnKeyAutomatically: true, fieldKind: .normal)
        #expect(h.controller.state.enterKeyDisabled)
        h.flick("あ")
        #expect(!h.controller.state.enterKeyDisabled)
    }
}
