#if canImport(UIKit)
import UIKit
import KeyFlowCore

public protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, perform action: KeyAction)
    /// キーに触れた瞬間（振動・クリック音のため）
    func keyboardViewDidTouchDown(_ view: KeyboardView)
}

/// キー領域。全キーのタッチを1か所で処理する。
///
/// - 複数の指で素早く打ったとき（ロールオーバー）、後の指が触れた時点で前の指の入力を確定し、順番が入れ替わらないようにする
/// - キー間の隙間に触れても最寄りのキーが反応する（`KeyboardGeometry.key(at:)`）
/// - 削除・カーソルキーは長押しで連続動作する
/// - 空白キーを横にドラッグするとカーソルを動かす
public final class KeyboardView: UIView {
    public weak var delegate: (any KeyboardViewDelegate)?

    public private(set) var spec: KeyboardLayoutSpec
    public private(set) var settings: KeyboardSettings
    public private(set) var isLandscape = false
    private var state = InputViewState()
    private var geometry: KeyboardGeometry?
    private var keyViews: [String: KeyCapView] = [:]
    private let guideView = FlickGuideView()
    private let previewView = KeyPreviewView()
    /// 地球儀キー。システムのキーボード一覧を出すため、ホスト側でターゲットを設定する。
    public let globeButton = UIButton(type: .custom)
    private let oneHandedBar = UIStackView()

    /// タッチ列をキー操作に変える処理（UIKit非依存。KeyFlowCoreでテスト済み）
    private let processor = KeyTouchProcessor()
    /// 長押し・連続動作のための時計。処理待ちのタッチがある間だけ動かす。
    private var ticker: Timer?
    /// 空白キーでカーソル移動中の表示をしているか
    private var showsCursorDragLabel = false

    public init(spec: KeyboardLayoutSpec, settings: KeyboardSettings) {
        self.spec = spec
        self.settings = settings
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
        clipsToBounds = false

        guideView.isHidden = true
        previewView.isHidden = true
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = KeyboardTheme.label
        globeButton.isHidden = true
        globeButton.accessibilityLabel = "次のキーボード"

        oneHandedBar.axis = .vertical
        oneHandedBar.alignment = .center
        oneHandedBar.distribution = .equalSpacing
        oneHandedBar.isHidden = true

        processor.config = KeyTouchProcessor.Config(settings: settings)
        processor.onAction = { [weak self] action in
            self?.perform(action)
        }
        processor.onTouchDown = { [weak self] in
            guard let self else { return }
            self.delegate?.keyboardViewDidTouchDown(self)
        }
        processor.onVisualChange = { [weak self] visual in
            self?.applyVisual(visual)
        }

        rebuildKeys()
        addSubview(globeButton)
        addSubview(oneHandedBar)
        addSubview(guideView)
        addSubview(previewView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 外部からの更新

    public func update(spec: KeyboardLayoutSpec, settings: KeyboardSettings, isLandscape: Bool) {
        let specChanged = spec != self.spec
        let layoutChanged = specChanged || settings != self.settings || isLandscape != self.isLandscape
        self.spec = spec
        self.settings = settings
        self.isLandscape = isLandscape
        processor.config = KeyTouchProcessor.Config(settings: settings)
        if specChanged {
            processor.cancelAll()
            rebuildKeys()
        }
        if layoutChanged {
            geometry = nil
            renderedSignatures.removeAll()
            refreshDynamicKeys()
            setNeedsLayout()
        }
    }

    public func apply(state: InputViewState) {
        guard state != self.state else { return }
        self.state = state
        processor.isShiftActive = state.shift != .off
        processor.isEnterDisabled = state.enterKeyDisabled
        refreshDynamicKeys()
        for key in spec.keys {
            elementsByID[key.id]?.accessibilityLabel = accessibilityName(for: key)
        }
    }

    // MARK: - キーの生成とレイアウト

    private func rebuildKeys() {
        keyViews.values.forEach { $0.removeFromSuperview() }
        keyViews.removeAll()
        for key in spec.keys {
            let view = KeyCapView()
            insertSubview(view, at: 0)
            keyViews[key.id] = view
        }
        globeButton.isHidden = !spec.keys.contains { $0.kind == .nextKeyboard }
        renderedSignatures.removeAll()
        refreshDynamicKeys()
        rebuildOneHandedBar()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if geometry == nil || geometry?.size != bounds.size {
            var s = settings
            // キー領域の高さはビューの実際の高さに合わせる（候補バーを除いた高さが渡される）
            if isLandscape {
                s.landscapeKeyAreaHeight = Double(bounds.height)
            } else {
                s.portraitKeyAreaHeight = Double(bounds.height)
            }
            let context = LayoutContext(width: Double(bounds.width), isLandscape: isLandscape, settings: s)
            geometry = LayoutEngine.layout(spec, context: context)
            processor.geometry = geometry
        }
        guard let geometry else { return }
        for key in geometry.keys {
            guard let view = keyViews[key.definition.id] else { continue }
            view.frame = key.frame
            view.cornerRadius = CGFloat(settings.keyCornerRadius)
            if case .nextKeyboard = key.definition.kind {
                globeButton.frame = key.frame
            }
        }
        guideView.frame = bounds
        layoutOneHandedBar(geometry)
        rebuildAccessibilityElements(geometry)
    }

    // MARK: - アクセシビリティ（VoiceOverとUIテスト用）

    private final class KeyElement: UIAccessibilityElement {
        var activate: (() -> Void)?
        override func accessibilityActivate() -> Bool {
            activate?()
            return true
        }
    }

    private var keyElements: [Any] = []
    private var elementsByID: [String: UIAccessibilityElement] = [:]

    public override var accessibilityElements: [Any]? {
        get { keyElements }
        set {}
    }

    private func accessibilityName(for key: KeyDefinition) -> String {
        switch key.kind {
        case let .flick(spec): return spec.label
        case let .character(text): return state.shift != .off ? text.uppercased() : text
        case .modifier: return "濁点・小文字"
        case .delete: return "削除"
        case .space: return state.spaceKeyLabel
        case .enter: return state.enterKeyLabel
        case .cursorLeft: return "左へ"
        case .cursorRight: return "右へ"
        case .shift: return "シフト"
        case let .switchMode(mode): return label(for: mode)
        case .nextKeyboard: return "次のキーボード"
        case .caseToggle: return "大文字・小文字の切り替え"
        }
    }

    private func rebuildAccessibilityElements(_ geometry: KeyboardGeometry) {
        var elements: [Any] = []
        elementsByID.removeAll()
        for key in geometry.keys {
            if case .nextKeyboard = key.definition.kind {
                continue
            }
            let element = KeyElement(accessibilityContainer: self)
            element.accessibilityFrameInContainerSpace = key.frame
            element.accessibilityLabel = accessibilityName(for: key.definition)
            element.accessibilityIdentifier = "key.\(key.definition.id)"
            element.accessibilityTraits = .keyboardKey
            element.activate = { [weak self] in
                self?.activateByAccessibility(key)
            }
            elements.append(element)
            elementsByID[key.definition.id] = element
        }
        if !globeButton.isHidden {
            elements.append(globeButton)
        }
        keyElements = elements
    }

    /// VoiceOverでキーを実行したとき（タップと同じ動作）
    private func activateByAccessibility(_ key: LaidOutKey) {
        delegate?.keyboardViewDidTouchDown(self)
        switch key.definition.kind {
        case let .flick(spec): perform(.flick(keyID: key.definition.id, spec: spec, direction: .center))
        case let .character(text): perform(.character(text))
        case .modifier: perform(.modifier(.center))
        case .delete: perform(.delete)
        case .space: perform(.space)
        case .enter: if !state.enterKeyDisabled { perform(.enter) }
        case .cursorLeft: perform(.cursorLeft)
        case .cursorRight: perform(.cursorRight)
        case .shift: perform(.shift)
        case let .switchMode(mode): perform(.switchMode(mode))
        case .caseToggle: perform(.toggleCase)
        case .nextKeyboard: break
        }
    }

    private func label(for mode: KeyboardMode) -> String {
        switch mode {
        case .kana: return "あいう"
        case .english: return "ABC"
        case .number: return "☆123"
        }
    }

    /// キーごとに最後に描いた内容。変わったキーだけ描き直す（打鍵ごとに全キーを更新しないため）
    private var renderedSignatures: [String: String] = [:]

    private struct KeyAppearance {
        var title: String?
        var systemImage: String?
        var fontSize: CGFloat
        var style: KeyCapView.Style
        var hints: [FlickDirection: String] = [:]
        var subtitle: String?
        var enabled = true

        var signature: String {
            let h = hints.keys.sorted { $0.rawValue < $1.rawValue }.map { "\($0.rawValue)\(hints[$0] ?? "")" }.joined()
            return "\(title ?? "")|\(systemImage ?? "")|\(fontSize)|\(style)|\(h)|\(subtitle ?? "")|\(enabled)"
        }
    }

    private func appearance(for key: KeyDefinition) -> KeyAppearance {
        let fontSize = CGFloat(settings.kanaFontSize)
        let functionalFont = min(fontSize * 0.75, 17)
        switch key.kind {
        case let .flick(flickSpec):
            var hints: [FlickDirection: String] = [:]
            if settings.showsKeyHints, flickSpec.subLabel == nil, flickSpec.label.count == 1 {
                for d in [FlickDirection.left, .up, .right, .down] {
                    hints[d] = flickSpec.outputs[d]
                }
            }
            return KeyAppearance(title: flickSpec.label, fontSize: flickSpec.label.count > 2 ? fontSize * 0.75 : fontSize, style: .normal, hints: hints, subtitle: flickSpec.subLabel)
        case let .character(text):
            let shown = state.shift != .off ? text.uppercased() : text
            return KeyAppearance(title: shown, fontSize: fontSize, style: .normal)
        case .modifier:
            return KeyAppearance(title: "小゛゜", fontSize: fontSize * 0.75, style: .normal)
        case .delete:
            return KeyAppearance(systemImage: "delete.left", fontSize: fontSize, style: .functional)
        case .space:
            // QWERTY系（英字・ローマ字）は標準キーボードと同じく白い空白キーにする
            return KeyAppearance(title: state.spaceKeyLabel, fontSize: functionalFont, style: spec.isRowBased ? .normal : .functional)
        case .enter:
            return KeyAppearance(title: state.enterKeyLabel, fontSize: functionalFont, style: state.enterKeyEmphasized ? .accent : .functional, enabled: !state.enterKeyDisabled)
        case .cursorLeft:
            return KeyAppearance(systemImage: state.isToggleActive ? "arrow.uturn.backward" : "chevron.left", fontSize: fontSize, style: .functional)
        case .cursorRight:
            return KeyAppearance(systemImage: state.isToggleActive ? "arrow.right" : "chevron.right", fontSize: fontSize, style: .functional)
        case .shift:
            let image: String
            switch state.shift {
            case .off: image = "shift"
            case .once: image = "shift.fill"
            case .locked: image = "capslock.fill"
            }
            return KeyAppearance(systemImage: image, fontSize: fontSize, style: state.shift == .off ? .functional : .normal)
        case let .switchMode(target):
            return KeyAppearance(title: label(for: target), fontSize: functionalFont, style: .functional)
        case .nextKeyboard:
            return KeyAppearance(systemImage: "globe", fontSize: fontSize, style: .functional)
        case .caseToggle:
            return KeyAppearance(title: "a/A", fontSize: fontSize * 0.8, style: .normal)
        }
    }

    /// 入力状態によって表示が変わるキーを更新する
    private func refreshDynamicKeys() {
        for key in spec.keys {
            guard let view = keyViews[key.id] else { continue }
            let a = appearance(for: key)
            let signature = a.signature
            guard renderedSignatures[key.id] != signature else { continue }
            renderedSignatures[key.id] = signature
            view.configure(title: a.title, systemImage: a.systemImage, fontSize: a.fontSize, style: a.style, hints: a.hints, subtitle: a.subtitle)
            view.isEnabled = a.enabled
        }
    }

    // MARK: - 片手モードの操作ボタン

    private func rebuildOneHandedBar() {
        oneHandedBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let swap = UIButton(type: .system)
        swap.setImage(UIImage(systemName: "arrow.left.arrow.right"), for: .normal)
        swap.accessibilityLabel = "反対側に寄せる"
        swap.addTarget(self, action: #selector(swapOneHandedSide), for: .touchUpInside)
        let exit = UIButton(type: .system)
        exit.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        exit.accessibilityLabel = "片手モードを終了"
        exit.addTarget(self, action: #selector(exitOneHanded), for: .touchUpInside)
        for b in [swap, exit] {
            b.tintColor = KeyboardTheme.secondaryLabel
            oneHandedBar.addArrangedSubview(b)
        }
    }

    private func layoutOneHandedBar(_ geometry: KeyboardGeometry) {
        let active = settings.oneHandedMode != .off && !isLandscape
        oneHandedBar.isHidden = !active
        guard active else { return }
        let content = geometry.contentFrame
        let freeWidth = bounds.width - content.width - CGFloat(settings.sideMargin) * 2
        let x: CGFloat = settings.oneHandedMode == .left ? content.maxX + CGFloat(settings.sideMargin) : 0
        oneHandedBar.frame = CGRect(x: x, y: bounds.height * 0.2, width: max(freeWidth, 30), height: bounds.height * 0.6)
    }

    @objc private func swapOneHandedSide() {
        delegate?.keyboardView(self, perform: .setOneHandedMode(settings.oneHandedMode == .left ? .right : .left))
    }

    @objc private func exitOneHanded() {
        delegate?.keyboardView(self, perform: .setOneHandedMode(.off))
    }

    // MARK: - タッチ処理

    private func touchID(_ touch: UITouch) -> Int {
        ObjectIdentifier(touch).hashValue
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 同時に触れた指は、触れた時刻の順に処理する
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            processor.touchBegan(id: touchID(touch), at: touch.location(in: self), time: touch.timestamp)
        }
        updateTicker()
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            processor.touchMoved(id: touchID(touch), to: touch.location(in: self), time: touch.timestamp)
        }
        updateTicker()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            processor.touchEnded(id: touchID(touch), at: touch.location(in: self), time: touch.timestamp)
        }
        updateTicker()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            processor.touchCancelled(id: touchID(touch))
        }
        updateTicker()
    }

    /// 長押し・連続動作の処理待ちがある間だけ、時計を動かす
    private func updateTicker() {
        if processor.needsTicks {
            guard ticker == nil else { return }
            let timer = Timer(timeInterval: 0.01, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.processor.tick(time: ProcessInfo.processInfo.systemUptime)
                if !self.processor.needsTicks {
                    self.ticker?.invalidate()
                    self.ticker = nil
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else {
            ticker?.invalidate()
            ticker = nil
        }
    }

    /// 押下表示・フリック先の吹き出し・英字の拡大表示・カーソル移動中の表示を反映する
    private func applyVisual(_ visual: KeyTouchProcessor.VisualState) {
        for (id, view) in keyViews {
            let pressed = visual.pressedKeyIDs.contains(id)
            if view.isPressed != pressed {
                view.isPressed = pressed
            }
        }
        if let guide = visual.guide {
            guideView.show(outputs: guide.outputs, keyFrame: guide.keyFrame, active: guide.active, showsAll: guide.showsAll, fontSize: CGFloat(settings.kanaFontSize))
        } else {
            guideView.hide()
        }
        if let preview = visual.preview {
            previewView.show(text: preview.text, above: preview.keyFrame, fontSize: CGFloat(settings.kanaFontSize))
        } else {
            previewView.hide()
        }
        let dragging = visual.cursorDragKeyID != nil
        if dragging != showsCursorDragLabel {
            showsCursorDragLabel = dragging
            if let id = visual.cursorDragKeyID ?? spec.keys.first(where: { $0.kind == .space })?.id {
                renderedSignatures[id] = nil
                if dragging {
                    keyViews[id]?.configure(title: "◀︎ カーソル ▶︎", fontSize: 14, style: .functional)
                } else {
                    refreshDynamicKeys()
                }
            }
        }
    }

    private func perform(_ action: KeyAction) {
        delegate?.keyboardView(self, perform: action)
    }
}
#endif
