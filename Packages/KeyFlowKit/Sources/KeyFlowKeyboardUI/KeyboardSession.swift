#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// キーボード全体のビュー（候補バー＋キー領域＋重ねて表示するパネル）
public final class KeyboardRootView: UIView, UIInputViewAudioFeedback {
    public let candidateBar = CandidateBarView()
    public let keyboardView: KeyboardView
    var overlay: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let overlay {
                addSubview(overlay)
            }
            setNeedsLayout()
        }
    }
    var candidateBarHeight: CGFloat = 42 {
        didSet { if oldValue != candidateBarHeight { setNeedsLayout() } }
    }

    public var enableInputClicksWhenVisible: Bool { true }

    init(keyboardView: KeyboardView) {
        self.keyboardView = keyboardView
        super.init(frame: .zero)
        backgroundColor = KeyboardTheme.background
        // フリック先の吹き出しが候補バーの上に重なるよう、キー領域を手前に置く
        addSubview(candidateBar)
        addSubview(keyboardView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        candidateBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: candidateBarHeight)
        let keyArea = CGRect(x: 0, y: candidateBarHeight, width: bounds.width, height: max(bounds.height - candidateBarHeight, 0))
        keyboardView.frame = keyArea
        overlay?.frame = keyArea
    }
}

/// 振動・クリック音
final class KeyboardFeedback {
    private var generator: UIImpactFeedbackGenerator?

    func touchDown(haptic: Bool, sound: Bool) {
        if haptic {
            if generator == nil {
                generator = UIImpactFeedbackGenerator(style: .light)
            }
            generator?.impactOccurred(intensity: 0.7)
            generator?.prepare()
        }
        if sound {
            UIDevice.current.playInputClick()
        }
    }
}

/// 入力状態管理（`InputController`）と表示をつなぐ。
/// キーボード拡張とアプリ内のプレビューの両方で使う。
public final class KeyboardSession: NSObject, KeyboardViewDelegate, CandidateBarDelegate {
    public let rootView: KeyboardRootView
    public let controller: InputController
    public private(set) var settings: KeyboardSettings
    public var showsGlobeKey = false {
        didSet { if oldValue != showsGlobeKey { refreshLayout() } }
    }
    public var isLandscape = false {
        didSet { if oldValue != isLandscape { refreshLayout() } }
    }
    public var hasFullAccess = false

    /// キーボード上で設定を変えたとき（保存は呼び出し側で行う）
    public var onSettingsChange: ((KeyboardSettings) -> Void)?
    /// キーボードを閉じるボタン
    public var onDismiss: (() -> Void)?
    /// 高さが変わる設定の変更があったとき
    public var onHeightChange: (() -> Void)?
    /// 入力状態が変わったとき（アプリ内プレビューで入力結果を表示するため）
    public var onStateChange: ((InputViewState) -> Void)?

    private let feedback = KeyboardFeedback()
    private var mode: KeyboardMode = .kana
    private let grid = CandidateGridView()

    public init(controller: InputController, settings: KeyboardSettings) {
        let normalized = settings.normalized()
        self.controller = controller
        self.settings = normalized
        let spec = KeyboardLayouts.layout(for: .kana, showsGlobeKey: false)
        let keyboardView = KeyboardView(spec: spec, settings: normalized)
        self.rootView = KeyboardRootView(keyboardView: keyboardView)
        super.init()
        keyboardView.delegate = self
        rootView.candidateBar.delegate = self
        rootView.candidateBarHeight = CGFloat(normalized.candidateBarHeight)
        rootView.candidateBar.fontSize = CGFloat(normalized.candidateFontSize)
        grid.onSelect = { [weak self] index, requestID in
            self?.closeOverlay()
            self?.controller.selectCandidate(at: index, requestID: requestID)
        }
        grid.onClose = { [weak self] in
            self?.closeOverlay()
        }
        controller.settings = normalized
        controller.onStateChange = { [weak self] state in
            self?.apply(state)
        }
        apply(controller.state)
        refreshLayout()
    }

    /// キーボード全体の高さ（候補バーを含む）
    public var preferredHeight: CGFloat {
        CGFloat(settings.candidateBarHeight + (isLandscape ? settings.landscapeKeyAreaHeight : settings.portraitKeyAreaHeight))
    }

    /// 保存済みの設定を反映する
    public func updateSettings(_ newSettings: KeyboardSettings) {
        let normalized = newSettings.normalized()
        guard normalized != settings else { return }
        let heightChanged = preferredHeight != CGFloat(normalized.candidateBarHeight + (isLandscape ? normalized.landscapeKeyAreaHeight : normalized.portraitKeyAreaHeight))
        settings = normalized
        controller.settings = normalized
        rootView.candidateBarHeight = CGFloat(normalized.candidateBarHeight)
        rootView.candidateBar.fontSize = CGFloat(normalized.candidateFontSize)
        grid.fontSize = CGFloat(normalized.candidateFontSize)
        refreshLayout()
        if heightChanged {
            onHeightChange?()
        }
    }

    private func changeSettingsFromKeyboard(_ newSettings: KeyboardSettings) {
        var s = newSettings
        s.updatedAt = Date()
        updateSettings(s)
        onSettingsChange?(settings)
    }

    private func refreshLayout() {
        let spec = KeyboardLayouts.layout(for: mode, showsGlobeKey: showsGlobeKey)
        var layoutSpec = spec
        if spec.columnWeights.count == 5 {
            layoutSpec = spec.mode == .kana
                ? KeyboardLayouts.kana(showsGlobeKey: showsGlobeKey, sideColumnWeight: settings.sideColumnRatio)
                : KeyboardLayouts.number(showsGlobeKey: showsGlobeKey, sideColumnWeight: settings.sideColumnRatio)
        }
        rootView.keyboardView.update(spec: layoutSpec, settings: settings, isLandscape: isLandscape)
    }

    private func apply(_ state: InputViewState) {
        if state.mode != mode {
            mode = state.mode
            refreshLayout()
        }
        rootView.keyboardView.apply(state: state)
        rootView.candidateBar.apply(state: state)
        if rootView.overlay === grid {
            if state.candidates.isEmpty {
                closeOverlay()
            } else {
                grid.show(candidates: state.candidates, requestID: state.candidateRequestID)
            }
        }
        onStateChange?(state)
    }

    private func closeOverlay() {
        rootView.overlay = nil
    }

    // MARK: - KeyboardViewDelegate

    public func keyboardView(_ view: KeyboardView, perform action: KeyAction) {
        switch action {
        case let .flick(keyID, spec, direction):
            controller.flick(keyID: keyID, spec: spec, direction: direction)
        case let .character(text):
            controller.character(text)
        case let .modifier(direction):
            controller.modifier(direction: direction)
        case .delete:
            controller.delete()
        case .space:
            controller.space()
        case .enter:
            controller.enter()
        case .cursorLeft:
            controller.cursorLeft()
        case .cursorRight:
            controller.cursorRight()
        case let .moveCursor(offset):
            controller.moveCursor(by: offset)
        case .shift:
            controller.toggleShift()
        case let .switchMode(target):
            controller.switchMode(to: target)
        case let .setOneHandedMode(oneHanded):
            var s = settings
            s.oneHandedMode = oneHanded
            changeSettingsFromKeyboard(s)
        }
    }

    public func keyboardViewDidTouchDown(_ view: KeyboardView) {
        feedback.touchDown(haptic: settings.hapticFeedback, sound: settings.keySound)
    }

    // MARK: - CandidateBarDelegate

    public func candidateBar(_ bar: CandidateBarView, didSelect index: Int, requestID: Int) {
        feedback.touchDown(haptic: settings.hapticFeedback, sound: settings.keySound)
        controller.selectCandidate(at: index, requestID: requestID)
    }

    public func candidateBarDidTapUndo(_ bar: CandidateBarView) {
        controller.undoLastCommit()
    }

    public func candidateBarDidTapExpand(_ bar: CandidateBarView) {
        if rootView.overlay === grid {
            closeOverlay()
            return
        }
        grid.fontSize = CGFloat(settings.candidateFontSize)
        grid.show(candidates: controller.state.candidates, requestID: controller.state.candidateRequestID)
        rootView.overlay = grid
    }

    public func candidateBarDidTapSettings(_ bar: CandidateBarView) {
        if rootView.overlay is QuickSettingsView {
            closeOverlay()
            return
        }
        let panel = QuickSettingsView(settings: settings, isLandscape: isLandscape, hasFullAccess: hasFullAccess)
        panel.onChange = { [weak self] s in
            self?.changeSettingsFromKeyboard(s)
        }
        panel.onClose = { [weak self] in
            self?.closeOverlay()
        }
        rootView.overlay = panel
    }

    public func candidateBarDidTapDismiss(_ bar: CandidateBarView) {
        onDismiss?()
    }
}
#endif
