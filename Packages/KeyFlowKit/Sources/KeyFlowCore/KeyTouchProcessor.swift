import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// キーを押したときに起こす操作
public enum KeyAction: Equatable, Sendable {
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
    case toggleCase
}

/// タッチの列（開始・移動・終了と時刻）を、キー操作に変換する。
///
/// UIKitに依存しないので、指の動きを座標と時刻で再現してテストできる。
/// - 複数の指で素早く打ったとき（ロールオーバー）、後の指が触れた時点で前の指の入力をその時点の方向で確定する
/// - 削除・カーソルキーは長押しで連続動作する（`tick`で時間を進める）
/// - 空白キーは横にドラッグするか長押しするとカーソル移動になり、離しても空白は入らない
/// - 英字キーは指をずらすと、離したときに指の下にあるキーを入力する
public final class KeyTouchProcessor {
    public struct Config: Equatable, Sendable {
        public var flickThreshold: Double = 20
        public var showsFlickGuide = true
        public var deleteRepeatDelay: Double = 0.45
        public var deleteRepeatInterval: Double = 0.06
        /// 連続削除が続いたら速くする（この回数を超えたら間隔を半分に）
        public var deleteAccelerateAfter = 20
        public var cursorRepeatDelay: Double = 0.4
        public var cursorRepeatInterval: Double = 0.07
        public var spaceHoldDelay: Double = 0.45
        /// 空白キーをこれ以上横に動かしたらカーソル移動にする（pt）
        public var spaceDragStart: Double = 12
        /// カーソル移動1文字あたりの距離（pt）
        public var cursorDragStep: Double = 11
        /// 長押しでフリック先を十字に全部表示するまでの時間
        public var fullGuideDelay: Double = 0.35

        public init() {}

        public init(settings: KeyboardSettings) {
            flickThreshold = settings.flickThreshold
            showsFlickGuide = settings.showsFlickGuide
            deleteRepeatDelay = settings.deleteRepeatDelay
            cursorDragStep = settings.cursorDragStep
        }
    }

    /// フリック先の表示
    public struct Guide: Equatable, Sendable {
        public var keyID: String
        public var keyFrame: CGRect
        public var outputs: [FlickDirection: String]
        public var active: FlickDirection
        /// 5方向すべてを表示する（長押し時）
        public var showsAll: Bool
    }

    /// 英字キーの拡大表示
    public struct Preview: Equatable, Sendable {
        public var text: String
        public var keyFrame: CGRect
    }

    /// 表示に必要な状態
    public struct VisualState: Equatable, Sendable {
        public var pressedKeyIDs: Set<String> = []
        public var guide: Guide?
        public var preview: Preview?
        /// 空白キーでカーソル移動中
        public var cursorDragKeyID: String?
    }

    public var geometry: KeyboardGeometry?
    public var config = Config()
    /// 英字の拡大表示を大文字にする
    public var isShiftActive = false
    /// 改行キーを押せない状態
    public var isEnterDisabled = false

    public var onAction: ((KeyAction) -> Void)?
    /// キーに触れた瞬間（振動・クリック音）
    public var onTouchDown: (() -> Void)?
    public var onVisualChange: ((VisualState) -> Void)?

    public private(set) var visual = VisualState()

    private final class Touch {
        let id: Int
        var key: LaidOutKey
        let start: CGPoint
        var current: CGPoint
        var direction: FlickDirection = .center
        var finished = false
        var isDraggingCursor = false
        var dragAnchorX: Double = 0
        var showsFullGuide = false
        /// 次に長押し・連続動作の処理をする時刻
        var nextFire: TimeInterval?
        var repeatCount = 0
        let began: TimeInterval

        init(id: Int, key: LaidOutKey, start: CGPoint, time: TimeInterval) {
            self.id = id
            self.key = key
            self.start = start
            self.current = start
            self.began = time
        }
    }

    /// 触れた順に保持する（ロールオーバーの確定順を守るため）
    private var touches: [Touch] = []

    public init() {}

    /// 長押し・連続動作の処理を待っているタッチがある（UI側はこの間だけ`tick`を呼べばよい）
    public var needsTicks: Bool {
        touches.contains { !$0.finished && $0.nextFire != nil }
    }

    private var classifier: FlickClassifier { FlickClassifier(threshold: config.flickThreshold) }

    // MARK: - タッチ

    public func touchBegan(id: Int, at point: CGPoint, time: TimeInterval) {
        guard let key = geometry?.key(at: point) else { return }
        if case .nextKeyboard = key.definition.kind {
            // 地球儀キーはシステムのボタンが扱う
            return
        }
        finishPendingCharacterTouches()
        let touch = Touch(id: id, key: key, start: point, time: time)
        touches.append(touch)
        onTouchDown?()
        visual.pressedKeyIDs.insert(key.definition.id)
        begin(touch, time: time)
        publish()
    }

    public func touchMoved(id: Int, to point: CGPoint, time: TimeInterval) {
        guard let touch = touches.first(where: { $0.id == id }), !touch.finished else { return }
        touch.current = point
        move(touch)
        publish()
    }

    public func touchEnded(id: Int, at point: CGPoint, time: TimeInterval) {
        guard let index = touches.firstIndex(where: { $0.id == id }) else { return }
        let touch = touches[index]
        if !touch.finished {
            touch.current = point
            move(touch)
            finish(touch)
        }
        touches.remove(at: index)
        release(touch)
        publish()
    }

    /// システムにタッチを奪われたとき。入力はしない。
    public func touchCancelled(id: Int) {
        guard let index = touches.firstIndex(where: { $0.id == id }) else { return }
        let touch = touches.remove(at: index)
        touch.finished = true
        release(touch)
        publish()
    }

    public func cancelAll() {
        let all = touches
        touches.removeAll()
        for t in all {
            t.finished = true
            release(t)
        }
        publish()
    }

    /// 時間を進めて、長押し・連続動作を処理する
    public func tick(time: TimeInterval) {
        var changed = false
        for touch in touches where !touch.finished {
            guard let due = touch.nextFire, time >= due else { continue }
            changed = true
            switch touch.key.definition.kind {
            case .delete:
                emit(.delete)
                touch.repeatCount += 1
                let interval = touch.repeatCount > config.deleteAccelerateAfter ? config.deleteRepeatInterval / 2 : config.deleteRepeatInterval
                touch.nextFire = time + interval
            case .cursorLeft:
                emit(.cursorLeft)
                touch.nextFire = time + config.cursorRepeatInterval
            case .cursorRight:
                emit(.cursorRight)
                touch.nextFire = time + config.cursorRepeatInterval
            case .space:
                touch.nextFire = nil
                if !touch.isDraggingCursor {
                    touch.isDraggingCursor = true
                    touch.dragAnchorX = Double(touch.current.x)
                    visual.cursorDragKeyID = touch.key.definition.id
                }
            case .flick:
                touch.nextFire = nil
                touch.showsFullGuide = true
                updateGuide(touch)
            default:
                touch.nextFire = nil
            }
        }
        if changed {
            publish()
        }
    }

    // MARK: - 内部処理

    private func begin(_ touch: Touch, time: TimeInterval) {
        switch touch.key.definition.kind {
        case .delete:
            emit(.delete)
            touch.nextFire = time + config.deleteRepeatDelay
        case .cursorLeft:
            emit(.cursorLeft)
            touch.nextFire = time + config.cursorRepeatDelay
        case .cursorRight:
            emit(.cursorRight)
            touch.nextFire = time + config.cursorRepeatDelay
        case .shift:
            emit(.shift)
        case .space:
            touch.nextFire = time + config.spaceHoldDelay
        case .flick:
            if config.showsFlickGuide {
                touch.nextFire = time + config.fullGuideDelay
            }
        case let .character(text):
            visual.preview = Preview(text: isShiftActive ? text.uppercased() : text, keyFrame: touch.key.frame)
        default:
            break
        }
    }

    private func move(_ touch: Touch) {
        let dx = Double(touch.current.x - touch.start.x)
        let dy = Double(touch.current.y - touch.start.y)
        switch touch.key.definition.kind {
        case .flick:
            let direction = classifier.direction(dx: dx, dy: dy)
            if direction != touch.direction {
                touch.direction = direction
                // 方向が決まったら長押しの全表示は待たない
                if direction != .center {
                    touch.nextFire = nil
                }
            }
            updateGuide(touch)
        case .modifier:
            touch.direction = classifier.direction(dx: dx, dy: dy)
        case .space:
            if !touch.isDraggingCursor, abs(dx) > config.spaceDragStart {
                touch.isDraggingCursor = true
                touch.nextFire = nil
                touch.dragAnchorX = Double(touch.current.x)
                visual.cursorDragKeyID = touch.key.definition.id
            }
            if touch.isDraggingCursor {
                let steps = Int((Double(touch.current.x) - touch.dragAnchorX) / config.cursorDragStep)
                if steps != 0 {
                    touch.dragAnchorX += Double(steps) * config.cursorDragStep
                    emit(.moveCursor(steps))
                }
            }
        case .character:
            // 指をずらした先の英字キーで入力する
            if let key = geometry?.key(at: touch.current), key.definition.id != touch.key.definition.id,
               case let .character(text) = key.definition.kind {
                visual.pressedKeyIDs.remove(touch.key.definition.id)
                touch.key = key
                visual.pressedKeyIDs.insert(key.definition.id)
                visual.preview = Preview(text: isShiftActive ? text.uppercased() : text, keyFrame: key.frame)
            }
        default:
            break
        }
    }

    /// 指を離した（またはロールオーバーで確定した）ときの入力
    private func finish(_ touch: Touch) {
        guard !touch.finished else { return }
        touch.finished = true
        touch.nextFire = nil
        switch touch.key.definition.kind {
        case let .flick(spec):
            emit(.flick(keyID: touch.key.definition.id, spec: spec, direction: touch.direction))
        case .modifier:
            emit(.modifier(touch.direction))
        case let .character(text):
            emit(.character(text))
        case .space:
            if !touch.isDraggingCursor {
                emit(.space)
            }
        case .enter:
            if !isEnterDisabled {
                emit(.enter)
            }
        case let .switchMode(mode):
            emit(.switchMode(mode))
        case .caseToggle:
            emit(.toggleCase)
        case .delete, .cursorLeft, .cursorRight, .shift, .nextKeyboard:
            break
        }
    }

    /// 押下表示などを片付ける
    private func release(_ touch: Touch) {
        // 同じキーを別の指が押していれば押下表示は残す
        if !touches.contains(where: { $0.key.definition.id == touch.key.definition.id }) {
            visual.pressedKeyIDs.remove(touch.key.definition.id)
        }
        if visual.guide?.keyID == touch.key.definition.id {
            visual.guide = nil
        }
        if visual.preview?.keyFrame == touch.key.frame {
            visual.preview = nil
        }
        if visual.cursorDragKeyID == touch.key.definition.id, touch.isDraggingCursor {
            visual.cursorDragKeyID = nil
        }
    }

    /// ロールオーバー: まだ指が離れていない文字キーを、その時点の方向で確定する
    private func finishPendingCharacterTouches() {
        for touch in touches where !touch.finished {
            switch touch.key.definition.kind {
            case .flick, .modifier, .character:
                finish(touch)
                visual.pressedKeyIDs.remove(touch.key.definition.id)
                if visual.guide?.keyID == touch.key.definition.id {
                    visual.guide = nil
                }
                visual.preview = nil
            default:
                break
            }
        }
    }

    private func updateGuide(_ touch: Touch) {
        guard case let .flick(spec) = touch.key.definition.kind else { return }
        guard config.showsFlickGuide || touch.showsFullGuide else {
            visual.guide = nil
            return
        }
        // タップ中（方向なし・全表示なし）は吹き出しを出さない
        if touch.direction == .center && !touch.showsFullGuide {
            visual.guide = nil
            return
        }
        visual.guide = Guide(keyID: touch.key.definition.id, keyFrame: touch.key.frame, outputs: spec.outputs, active: touch.direction, showsAll: touch.showsFullGuide)
    }

    private func emit(_ action: KeyAction) {
        onAction?(action)
    }

    private func publish() {
        onVisualChange?(visual)
    }
}
