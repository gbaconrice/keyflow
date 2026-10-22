import XCTest

/// シミュレーターでKeyFlowをシステムのキーボードとして有効にし、実際のキーボード拡張で入力する。
///
/// CIでは事前に`AppleKeyboards`にKeyFlowだけを登録してから実行する（.github/workflows/build.yml）。
/// 手元で実行するときは、シミュレーターの「設定」でKeyFlowを追加しておくこと。
final class KeyboardExtensionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
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
        app.launchArguments += ["-KeyFlowResetSettings"]
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
        // 英単語の候補（端末内の辞書による補完）
        for c in "hel" {
            key(app, "en_\(c)").tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "24b-english-suggestions")
        let hello = app.staticTexts["hello"].firstMatch
        if hello.waitForExistence(timeout: 2) {
            hello.tap()
            Thread.sleep(forTimeInterval: 0.5)
            note("24b-text", (editor.value as? String) ?? "(nil)")
            XCTAssertEqual((editor.value as? String) ?? "", "今日はいい天気hello ")
        } else {
            note("24b-text", "候補に hello が見つからない: " + ((editor.value as? String) ?? "(nil)"))
        }
        key(app, "toKana").tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "25-extension-back-to-kana")
    }

    /// 入力中に入力欄をタップしても、文字が重複・消失しない（外部からの変更の検出）
    func testTapWhileComposing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
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

    /// キーボード上の調整パネルで日本語の配列を切り替える
    private func setKanaLayout(_ app: XCUIApplication, _ name: String) {
        let adjust = app.buttons["キーボードの調整"].firstMatch
        guard adjust.waitForExistence(timeout: 3) else {
            XCTFail("キーボードの調整ボタンが見つからない")
            return
        }
        adjust.tap()
        let segment = app.buttons[name].firstMatch
        if segment.waitForExistence(timeout: 3) {
            segment.tap()
        } else {
            XCTFail("「\(name)」が見つからない")
        }
        app.buttons["完了"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// ローマ字入力（QWERTY）に切り替えて入力・変換する
    func testRomajiInput() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
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
        setKanaLayout(app, "ローマ字")
        if key(app, "ro_k").waitForExistence(timeout: 5) {
            snap(app, "50-romaji")
            for c in "kyouhaiitenki" {
                key(app, "ro_\(c)").tap()
            }
            Thread.sleep(forTimeInterval: 1)
            snap(app, "51-romaji-composing")
            note("51-text", (editor.value as? String) ?? "(nil)")
            key(app, "space").tap()
            Thread.sleep(forTimeInterval: 0.5)
            key(app, "enter").tap()
            Thread.sleep(forTimeInterval: 0.5)
            snap(app, "52-romaji-committed")
            let text = (editor.value as? String) ?? ""
            note("52-text", text)
            XCTAssertEqual(text, "今日はいい天気")
            // QWERTY型の数字・記号配列
            key(app, "toNumber").tap()
            Thread.sleep(forTimeInterval: 0.5)
            snap(app, "53-romaji-number")
            key(app, "toKana").tap()
        } else {
            XCTFail("ローマ字の配列に切り替わらない")
        }
        // 他のテストに影響しないよう12キーに戻す（予測候補が出ていると調整ボタンが隠れるので、先に消去する）
        app.buttons["消去"].firstMatch.tap()
        key(app, "delete").tap()
        Thread.sleep(forTimeInterval: 1)
        setKanaLayout(app, "12キー")
        XCTAssertTrue(key(app, "a").waitForExistence(timeout: 5))
    }

    /// ダークモードと横画面で表示・入力できる
    func testDarkAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-KeyFlowForceDark"]
        app.launchArguments += ["-KeyFlowResetSettings"]
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
        snap(app, "40-dark-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        snap(app, "41-dark-landscape")
        // か左=き、ん=わ上
        flick(key(app, "ka"), dx: -40, dy: 0)
        flick(key(app, "wa"), dx: 0, dy: -40)
        Thread.sleep(forTimeInterval: 0.5)
        snap(app, "42-landscape-composing")
        key(app, "enter").tap()
        Thread.sleep(forTimeInterval: 0.5)
        let text = (editor.value as? String) ?? ""
        note("42-text", text)
        XCTAssertEqual(text, "きん")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        snap(app, "43-back-to-portrait")
    }
}
