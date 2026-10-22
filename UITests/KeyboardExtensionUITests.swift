import XCTest

/// シミュレーターでKeyFlowをシステムのキーボードとして有効にし、実際のキーボード拡張で入力する。
///
/// CIでは事前に`AppleKeyboards`にKeyFlowだけを登録してから実行する（.github/workflows/build.yml）。
/// 手元で実行するときは、シミュレーターの「設定」でKeyFlowを追加しておくこと。
final class KeyboardExtensionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func key(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)["key.\(id)"].firstMatch
    }

    private func flick(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))
    }

    func testTypingWithSystemKeyboard() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["試し打ち"].firstMatch.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        // キーボード拡張の起動と、辞書の準備を待つ
        Thread.sleep(forTimeInterval: 4)
        snap(app, "20-extension-shown")
        note("20-hierarchy", app.debugDescription)

        let keyA = key(app, "a")
        guard keyA.waitForExistence(timeout: 10) else {
            XCTFail("キーボード拡張のキーが見つからない（キーボードが表示されていない可能性）")
            return
        }

        // 「きょうはいいてんき」を入力して変換・確定する
        // き=か左, ょ=や下+小゛゜, う=あ上, は=は, い=あ左, い=あ左, て=た右, ん=わ上, き=か左
        flick(key(app, "ka"), dx: -40, dy: 0)
        flick(key(app, "ya"), dx: 0, dy: 40)
        key(app, "modifier").tap()
        flick(key(app, "a"), dx: 0, dy: -40)
        key(app, "ha").tap()
        key(app, "cursorRight").tap()
        flick(key(app, "a"), dx: -40, dy: 0)
        flick(key(app, "a"), dx: -40, dy: 0)
        flick(key(app, "ta"), dx: 40, dy: 0)
        flick(key(app, "wa"), dx: 0, dy: -40)
        flick(key(app, "ka"), dx: -40, dy: 0)
        Thread.sleep(forTimeInterval: 1)
        snap(app, "21-extension-composing")
        note("21-text", (editor.value as? String) ?? "(nil)")

        key(app, "space").tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "22-extension-converted")
        key(app, "enter").tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "23-extension-committed")
        let text = (editor.value as? String) ?? ""
        note("23-text", text)
        XCTAssertEqual(text, "今日はいい天気")

        // 確定後の次の語の予測と、英字への切り替え
        key(app, "toEnglish").tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "24-extension-english")
        key(app, "toKana").tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "25-extension-back-to-kana")
    }

    /// 入力中に入力欄をタップしても、文字が重複・消失しない（外部からの変更の検出）
    func testTapWhileComposing() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["試し打ち"].firstMatch.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        guard key(app, "a").waitForExistence(timeout: 10) else {
            XCTFail("キーボード拡張のキーが見つからない")
            return
        }
        Thread.sleep(forTimeInterval: 2)
        key(app, "a").tap()
        key(app, "cursorRight").tap()
        flick(key(app, "a"), dx: -40, dy: 0)
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "30-composing-before-tap")
        // 入力欄の空いているところ（文末の後ろ）をタップする
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)).tap()
        Thread.sleep(forTimeInterval: 1)
        flick(key(app, "a"), dx: 0, dy: -40)
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "31-typed-after-tap")
        key(app, "enter").tap()
        Thread.sleep(forTimeInterval: 0.5)
        let text = (editor.value as? String) ?? ""
        note("31-text", text)
        snap(app, "32-after-enter")
        XCTAssertEqual(text, "あいう", "入力中のタップで文字が重複・消失していないこと")
    }
}
