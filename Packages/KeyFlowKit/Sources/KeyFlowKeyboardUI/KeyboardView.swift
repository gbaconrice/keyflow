#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// キーを押したときに起こす操作
public enum KeyAction: Equatable {
    case flick(keyID: String, spec: FlickKeySpec, direction: FlickDirection)
    case character(String)
    case modifier(FlickDirection)
    case delete
    case space
    case enter
    case cursorLeft
    case cursorRight
    case moveCursor(Int)
    case shift
    case switchMode(KeyboardMode)
    case setOneHandedMode(OneHandedMode)
}

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

    private final class TouchState {
        var key: LaidOutKey
        let start: CGPoint
        var current: CGPoint
        var direction: FlickDirection = .center
        var repeatTimer: Timer?
        var holdTimer: Timer?
        var isDraggingCursor = false
        var dragAnchorX: CGFloat = 0
        var finished = false
        var showsAllGuide = false

        init(key: LaidOutKey, start: CGPoint) {
            self.key = key
            self.start = start
            self.current = start
        }

        func invalidateTimers() {
            repeatTimer?.invalidate()
            repeatTimer = nil
            holdTimer?.invalidate()
            holdTimer = nil
        }
    }

    private var touchStates: [ObjectIdentifier: TouchState] = [:]
    private var classifier: FlickClassifier { FlickClassifier(threshold: settings.flickThreshold) }

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
        if specChanged {
            cancelAllTouches()
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
            let shown = (spec.mode == .english && state.shift != .off) ? text.uppercased() : text
            return KeyAppearance(title: shown, fontSize: fontSize, style: .normal)
        case .modifier:
            return KeyAppearance(title: "小゛゜", fontSize: fontSize * 0.75, style: .normal)
        case .delete:
            return KeyAppearance(systemImage: "delete.left", fontSize: fontSize, style: .functional)
        case .space:
            return KeyAppearance(title: state.spaceKeyLabel, fontSize: functionalFont, style: spec.mode == .english ? .normal : .functional)
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

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard let key = geometry?.key(at: point) else { continue }
            if case .nextKeyboard = key.definition.kind {
                continue
            }
            // ロールオーバー: 先に押されている文字キーを確定してから次のキーを扱う
            finishPendingCharacterTouches()

            let ts = TouchState(key: key, start: point)
            touchStates[ObjectIdentifier(touch)] = ts
            delegate?.keyboardViewDidTouchDown(self)
            setPressed(key, true)
            beginTouch(ts)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let ts = touchStates[ObjectIdentifier(touch)], !ts.finished else { continue }
            ts.current = touch.location(in: self)
            moveTouch(ts)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let ts = touchStates[id] else { continue }
            ts.current = touch.location(in: self)
            if !ts.finished {
                if case .flick = ts.key.definition.kind {
                    ts.direction = classifier.direction(dx: Double(ts.current.x - ts.start.x), dy: Double(ts.current.y - ts.start.y))
                } else if case .modifier = ts.key.definition.kind {
                    ts.direction = classifier.direction(dx: Double(ts.current.x - ts.start.x), dy: Double(ts.current.y - ts.start.y))
                }
                endTouch(ts)
            }
            cleanup(ts)
            touchStates[id] = nil
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let ts = touchStates[id] else { continue }
            cleanup(ts)
            touchStates[id] = nil
        }
    }

    private func cancelAllTouches() {
        for ts in touchStates.values {
            cleanup(ts)
        }
        touchStates.removeAll()
    }

    private func beginTouch(_ ts: TouchState) {
        switch ts.key.definition.kind {
        case .delete:
            perform(.delete)
            startRepeat(ts, delay: settings.deleteRepeatDelay, interval: 0.06, action: .delete)
        case .cursorLeft:
            perform(.cursorLeft)
            startRepeat(ts, delay: 0.4, interval: 0.07, action: .cursorLeft)
        case .cursorRight:
            perform(.cursorRight)
            startRepeat(ts, delay: 0.4, interval: 0.07, action: .cursorRight)
        case .shift:
            perform(.shift)
        case .space:
            // 長押しでもカーソル移動モードに入る
            ts.holdTimer = scheduledTimer(after: 0.45) { [weak self, weak ts] in
                guard let self, let ts, !ts.finished, !ts.isDraggingCursor else { return }
                ts.isDraggingCursor = true
                ts.dragAnchorX = ts.current.x
                self.keyViews[ts.key.definition.id]?.configure(title: "◀︎ カーソル ▶︎", fontSize: 14, style: .functional)
                self.renderedSignatures[ts.key.definition.id] = nil
            }
        case let .flick(spec):
            if settings.showsFlickGuide {
                ts.holdTimer = scheduledTimer(after: 0.35) { [weak self, weak ts] in
                    guard let self, let ts, !ts.finished else { return }
                    ts.showsAllGuide = true
                    self.showGuide(ts, outputs: spec.outputs)
                }
            }
        case .character(let text):
            let shown = state.shift != .off ? text.uppercased() : text
            previewView.show(text: shown, above: ts.key.frame, fontSize: CGFloat(settings.kanaFontSize))
        default:
            break
        }
    }

    private func moveTouch(_ ts: TouchState) {
        let dx = Double(ts.current.x - ts.start.x)
        let dy = Double(ts.current.y - ts.start.y)
        switch ts.key.definition.kind {
        case let .flick(spec):
            let direction = classifier.direction(dx: dx, dy: dy)
            if direction != ts.direction {
                ts.direction = direction
                if settings.showsFlickGuide || ts.showsAllGuide {
                    showGuide(ts, outputs: spec.outputs)
                }
            }
        case .modifier:
            ts.direction = classifier.direction(dx: dx, dy: dy)
        case .space:
            let step = CGFloat(settings.cursorDragStep)
            if !ts.isDraggingCursor, abs(dx) > 12 {
                ts.isDraggingCursor = true
                ts.holdTimer?.invalidate()
                ts.dragAnchorX = ts.current.x
                keyViews[ts.key.definition.id]?.configure(title: "◀︎ カーソル ▶︎", fontSize: 14, style: .functional)
                renderedSignatures[ts.key.definition.id] = nil
            }
            if ts.isDraggingCursor {
                let steps = Int((ts.current.x - ts.dragAnchorX) / step)
                if steps != 0 {
                    ts.dragAnchorX += CGFloat(steps) * step
                    perform(.moveCursor(steps))
                }
            }
        case .character:
            // 指をずらした先のキーで入力する
            if let key = geometry?.key(at: ts.current), key.definition.id != ts.key.definition.id, case .character(let text) = key.definition.kind {
                setPressed(ts.key, false)
                ts.key = key
                setPressed(key, true)
                let shown = state.shift != .off ? text.uppercased() : text
                previewView.show(text: shown, above: key.frame, fontSize: CGFloat(settings.kanaFontSize))
            }
        case .delete:
            break
        default:
            break
        }
    }

    private func endTouch(_ ts: TouchState) {
        ts.finished = true
        switch ts.key.definition.kind {
        case let .flick(spec):
            perform(.flick(keyID: ts.key.definition.id, spec: spec, direction: ts.direction))
        case .modifier:
            perform(.modifier(ts.direction))
        case let .character(text):
            perform(.character(text))
        case .space:
            if !ts.isDraggingCursor {
                perform(.space)
            }
        case .enter:
            if !state.enterKeyDisabled {
                perform(.enter)
            }
        case let .switchMode(mode):
            perform(.switchMode(mode))
        case .delete, .cursorLeft, .cursorRight, .shift, .nextKeyboard:
            break
        }
    }

    /// ロールオーバー時に、まだ指が離れていない文字キーの入力をその時点の方向で確定する
    private func finishPendingCharacterTouches() {
        for ts in touchStates.values where !ts.finished {
            switch ts.key.definition.kind {
            case .flick, .modifier, .character:
                endTouch(ts)
                cleanup(ts)
            default:
                break
            }
        }
    }

    private func cleanup(_ ts: TouchState) {
        ts.finished = true
        ts.invalidateTimers()
        setPressed(ts.key, false)
        guideView.hide()
        previewView.hide()
        if case .space = ts.key.definition.kind, ts.isDraggingCursor {
            refreshDynamicKeys()
        }
    }

    private func perform(_ action: KeyAction) {
        delegate?.keyboardView(self, perform: action)
    }

    private func setPressed(_ key: LaidOutKey, _ pressed: Bool) {
        keyViews[key.definition.id]?.isPressed = pressed
    }

    private func showGuide(_ ts: TouchState, outputs: [FlickDirection: String]) {
        guideView.show(outputs: outputs, keyFrame: ts.key.frame, active: ts.direction, showsAll: ts.showsAllGuide, fontSize: CGFloat(settings.kanaFontSize))
    }

    private func startRepeat(_ ts: TouchState, delay: Double, interval: Double, action: KeyAction) {
        ts.holdTimer = scheduledTimer(after: delay) { [weak self, weak ts] in
            guard let self, let ts, !ts.finished else { return }
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak ts] timer in
                guard let self, let ts, !ts.finished else {
                    timer.invalidate()
                    return
                }
                self.perform(action)
            }
            RunLoop.main.add(timer, forMode: .common)
            ts.repeatTimer = timer
            self.perform(action)
        }
    }

    private func scheduledTimer(after delay: Double, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
#endif
