import XCTest

/// アプリ内のプレビューキーボードを操作し、画面を記録する。
/// 撮った画像はCIの成果物（screenshots）として保存される。
final class KeyFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func key(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)["key.\(id)"].firstMatch
    }

    /// キーの中心から指定方向にフリックする
    private func flick(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: dx, dy: dy))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func openLayoutSettings(_ app: XCUIApplication) {
        app.buttons["サイズと配置"].firstMatch.tap()
        XCTAssertTrue(key(app, "a").waitForExistence(timeout: 5), "プレビューのキーが見つからない")
    }

    func testHomeAndPreview() {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        snap(app, "01-home")
        openLayoutSettings(app)
        snap(app, "02-layout-settings")

        // 「かんじ」: か(タップ) → ん(わを上フリック) → し(さを左フリック) → 小゛゜で濁点
        key(app, "ka").tap()
        flick(key(app, "wa"), dx: 0, dy: -40)
        flick(key(app, "sa"), dx: -40, dy: 0)
        key(app, "modifier").tap()
        snap(app, "03-typed-kanji-reading")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "かんじ")).firstMatch.waitForExistence(timeout: 2), "入力した文字がプレビューに出ない")

        key(app, "space").tap()
        snap(app, "04-candidate-selected")
        key(app, "enter").tap()
        snap(app, "05-committed")
    }

    func testToggleAndCursorKeys() {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        openLayoutSettings(app)
        // あ を3回で「う」
        for _ in 0..<3 { key(app, "a").tap() }
        key(app, "cursorRight").tap()
        key(app, "a").tap()
        snap(app, "06-toggle")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "うあ")).firstMatch.waitForExistence(timeout: 2))
    }

    func testModesAndDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments = ["-KeyFlowForceDark"]
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        openLayoutSettings(app)
        snap(app, "07-dark-kana")
        key(app, "toEnglish").tap()
        snap(app, "08-dark-english")
        key(app, "toNumber").tap()
        snap(app, "09-dark-number")
    }

    func testOneHandedAndInputSettings() {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        app.buttons["入力操作"].firstMatch.tap()
        _ = key(app, "a").waitForExistence(timeout: 5)
        snap(app, "10-input-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openLayoutSettings(app)
        // 片手モード（右）に切り替える（下の方にあるので、見えるまでスクロールする）
        let right = app.buttons["右手"].firstMatch
        var swipes = 0
        while !(right.exists && right.isHittable), swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        if right.waitForExistence(timeout: 2) {
            right.tap()
            snap(app, "11-one-handed-right")
        } else {
            XCTFail("片手モードの選択肢が見つからない")
        }
    }

    /// 日本語の配列をローマ字（QWERTY）に切り替え、プレビューで打つ
    func testRomajiPreview() {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        app.buttons["入力操作"].firstMatch.tap()
        let romaji = app.buttons["ローマ字（QWERTY）"].firstMatch
        guard romaji.waitForExistence(timeout: 5) else {
            XCTFail("日本語の配列の選択肢が見つからない")
            return
        }
        romaji.tap()
        guard key(app, "ro_k").waitForExistence(timeout: 5) else {
            XCTFail("ローマ字の配列に切り替わらない")
            return
        }
        for c in "kanji" {
            key(app, "ro_\(c)").tap()
        }
        snap(app, "15-romaji-preview")
        app.buttons["12キー（フリック）"].firstMatch.tap()
    }

    func testPanels() {
        let app = XCUIApplication()
        app.launchArguments += ["-KeyFlowResetSettings"]
        app.launch()
        openLayoutSettings(app)

        // 記号・顔文字の一覧
        let symbols = app.buttons["記号と顔文字"].firstMatch
        if symbols.waitForExistence(timeout: 3) {
            symbols.tap()
            snap(app, "12-symbols")
            app.buttons["顔文字"].firstMatch.tap()
            snap(app, "13-kaomoji")
            app.buttons["閉じる"].firstMatch.tap()
        } else {
            XCTFail("記号と顔文字のボタンが見つからない")
        }

        // キーボード上の調整パネル
        let adjust = app.buttons["キーボードの調整"].firstMatch
        if adjust.waitForExistence(timeout: 3) {
            adjust.tap()
            snap(app, "14-quick-settings")
            app.buttons["完了"].firstMatch.tap()
        } else {
            XCTFail("キーボードの調整ボタンが見つからない")
        }

        // 候補の一覧（入力中に右端のボタン）
        key(app, "ka").tap()
        flick(key(app, "wa"), dx: 0, dy: -40)
        let expand = app.buttons["候補をすべて表示"].firstMatch
        if expand.waitForExistence(timeout: 3) {
            expand.tap()
            snap(app, "15-candidate-grid")
        } else {
            XCTFail("候補をすべて表示のボタンが見つからない")
        }
    }
}
