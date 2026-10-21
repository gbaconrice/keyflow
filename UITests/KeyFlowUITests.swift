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
        app.launch()
        app.buttons["入力操作"].firstMatch.tap()
        _ = key(app, "a").waitForExistence(timeout: 5)
        snap(app, "10-input-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openLayoutSettings(app)
        // 片手モード（右）に切り替える
        let picker = app.buttons["片手モード"].firstMatch
        if picker.waitForExistence(timeout: 2) {
            picker.tap()
            app.buttons["右手"].firstMatch.tap()
            snap(app, "11-one-handed-right")
        }
    }
}
