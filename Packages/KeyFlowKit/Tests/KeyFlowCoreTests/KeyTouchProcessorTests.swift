import Foundation
import Testing
@testable import KeyFlowCore

/// タッチ処理の再現テスト。座標と時刻を与えて、どの操作になるかを確かめる。
final class TouchHarness {
    let processor = KeyTouchProcessor()
    var actions: [KeyAction] = []
    var touchDowns = 0
    let geometry: KeyboardGeometry

    init(spec: KeyboardLayoutSpec = KeyboardLayouts.kana(showsGlobeKey: false), settings: KeyboardSettings = .default) {
        geometry = LayoutEngine.layout(spec, context: .init(width: 393, isLandscape: false, settings: settings))
        processor.geometry = geometry
        processor.config = .init(settings: settings)
        processor.onAction = { [unowned self] in self.actions.append($0) }
        processor.onTouchDown = { [unowned self] in self.touchDowns += 1 }
    }

    func center(_ id: String) -> CGPoint {
        let f = geometry.keys.first { $0.definition.id == id }!.frame
        return CGPoint(x: f.midX, y: f.midY)
    }

    func offset(_ p: CGPoint, _ dx: Double, _ dy: Double) -> CGPoint {
        CGPoint(x: p.x + dx, y: p.y + dy)
    }

    /// 押して離す（途中で指定した位置を通る）
    func stroke(_ id: Int, from start: CGPoint, through points: [CGPoint] = [], to end: CGPoint? = nil, at t: TimeInterval = 0) {
        processor.touchBegan(id: id, at: start, time: t)
        for (i, p) in points.enumerated() {
            processor.touchMoved(id: id, to: p, time: t + 0.01 * Double(i + 1))
        }
        processor.touchEnded(id: id, at: end ?? points.last ?? start, time: t + 0.05)
    }

    var flickOutputs: [String] {
        actions.compactMap {
            if case let .flick(_, spec, direction) = $0 { return spec.output(for: direction) }
            return nil
        }
    }
}

@Suite("タッチ処理")
struct KeyTouchProcessorTests {
    @Test("タップは中央の文字")
    func tap() {
        let h = TouchHarness()
        h.stroke(1, from: h.center("a"))
        #expect(h.flickOutputs == ["あ"])
        #expect(h.touchDowns == 1)
    }

    @Test("4方向のフリック")
    func flicks() {
        let h = TouchHarness()
        let a = h.center("a")
        h.stroke(1, from: a, through: [h.offset(a, -30, 0)])
        h.stroke(2, from: a, through: [h.offset(a, 0, -30)])
        h.stroke(3, from: a, through: [h.offset(a, 30, 0)])
        h.stroke(4, from: a, through: [h.offset(a, 0, 30)])
        #expect(h.flickOutputs == ["い", "う", "え", "お"])
    }

    @Test("少しずれただけのタップはフリックにならない")
    func jitter() {
        let h = TouchHarness()
        let ka = h.center("ka")
        h.stroke(1, from: ka, through: [h.offset(ka, 6, 5), h.offset(ka, 9, -4)])
        #expect(h.flickOutputs == ["か"])
    }

    @Test("フリックの途中で中央に戻すとタップになる")
    func flickBackToCenter() {
        let h = TouchHarness()
        let sa = h.center("sa")
        h.stroke(1, from: sa, through: [h.offset(sa, 35, 0), h.offset(sa, 3, 2)])
        #expect(h.flickOutputs == ["さ"])
    }

    @Test("キーの外まで大きくフリックしても、押し始めたキーの文字になる")
    func longFlick() {
        let h = TouchHarness()
        let na = h.center("na")
        h.stroke(1, from: na, through: [h.offset(na, -120, 5)])
        #expect(h.flickOutputs == ["に"])
    }

    @Test("ロールオーバー: 後の指が触れた時点で前の指の入力を確定し、順番を守る")
    func rollover() {
        let h = TouchHarness()
        let a = h.center("a")
        let ka = h.center("ka")
        h.processor.touchBegan(id: 1, at: a, time: 0)
        h.processor.touchMoved(id: 1, to: h.offset(a, 0, -30), time: 0.02)
        h.processor.touchBegan(id: 2, at: ka, time: 0.03)
        // この時点で「う」が確定している
        #expect(h.flickOutputs == ["う"])
        h.processor.touchEnded(id: 2, at: ka, time: 0.05)
        h.processor.touchEnded(id: 1, at: h.offset(a, 30, 0), time: 0.06)
        // 1本目は確定済みなので、離したときの位置（右）で入力し直さない
        #expect(h.flickOutputs == ["う", "か"])
    }

    @Test("3本の指が重なっても欠落しない")
    func tripleRollover() {
        let h = TouchHarness()
        h.processor.touchBegan(id: 1, at: h.center("a"), time: 0)
        h.processor.touchBegan(id: 2, at: h.center("ka"), time: 0.01)
        h.processor.touchBegan(id: 3, at: h.center("sa"), time: 0.02)
        h.processor.touchEnded(id: 1, at: h.center("a"), time: 0.03)
        h.processor.touchEnded(id: 3, at: h.center("sa"), time: 0.04)
        h.processor.touchEnded(id: 2, at: h.center("ka"), time: 0.05)
        #expect(h.flickOutputs == ["あ", "か", "さ"])
    }

    @Test("キャンセルされたタッチは入力しない")
    func cancel() {
        let h = TouchHarness()
        h.processor.touchBegan(id: 1, at: h.center("a"), time: 0)
        h.processor.touchCancelled(id: 1)
        #expect(h.actions.isEmpty)
        #expect(h.processor.visual.pressedKeyIDs.isEmpty)
    }

    @Test("削除キーは押した瞬間に1回、長押しで連続して消し、続くと速くなる")
    func deleteRepeat() {
        var s = KeyboardSettings()
        s.deleteRepeatDelay = 0.45
        let h = TouchHarness(settings: s)
        h.processor.touchBegan(id: 1, at: h.center("delete"), time: 0)
        #expect(h.actions == [.delete])
        h.processor.tick(time: 0.40)
        #expect(h.actions.count == 1)
        var t = 0.45
        while t < 1.0 {
            h.processor.tick(time: t)
            t += 0.01
        }
        let countAt1s = h.actions.count
        // 0.45秒から0.06秒ごと → およそ10回
        #expect(countAt1s >= 9 && countAt1s <= 12)
        while t < 3.0 {
            h.processor.tick(time: t)
            t += 0.01
        }
        let rateLate = Double(h.actions.count - countAt1s) / 2.0
        #expect(rateLate > 1.0 / 0.06, "続けると速くなる")
        h.processor.touchEnded(id: 1, at: h.center("delete"), time: 3.0)
        let finalCount = h.actions.count
        h.processor.tick(time: 4.0)
        #expect(h.actions.count == finalCount, "離したら止まる")
        #expect(!h.processor.needsTicks)
    }

    @Test("空白キーのタップは空白、横ドラッグはカーソル移動で空白は入らない")
    func spaceDrag() {
        let h = TouchHarness()
        let space = h.center("space")
        h.stroke(1, from: space)
        #expect(h.actions == [.space])
        h.actions.removeAll()
        // 12ptを超えたらカーソル移動。そこから11ptごとに1文字
        h.stroke(2, from: space, through: [h.offset(space, -13, 0), h.offset(space, -25, 0), h.offset(space, -40, 0)])
        #expect(!h.actions.contains(.space))
        let moved = h.actions.reduce(0) { sum, a in
            if case let .moveCursor(n) = a { return sum + n }
            return sum
        }
        #expect(moved == -2)
    }

    @Test("空白キーの長押しでカーソル移動になり、離しても空白は入らない")
    func spaceHold() {
        let h = TouchHarness()
        let space = h.center("space")
        h.processor.touchBegan(id: 1, at: space, time: 0)
        h.processor.tick(time: 0.5)
        #expect(h.processor.visual.cursorDragKeyID == "space")
        h.processor.touchMoved(id: 1, to: h.offset(space, 23, 0), time: 0.6)
        h.processor.touchEnded(id: 1, at: h.offset(space, 23, 0), time: 0.7)
        #expect(h.actions == [.moveCursor(2)])
        #expect(h.processor.visual.cursorDragKeyID == nil)
    }

    @Test("英字キーは指をずらすと離した位置のキーになる")
    func slideToCorrect() {
        let h = TouchHarness(spec: KeyboardLayouts.english(showsGlobeKey: false))
        h.stroke(1, from: h.center("en_q"), through: [h.center("en_w")])
        #expect(h.actions == [.character("w")])
        #expect(h.processor.visual.preview == nil)
    }

    @Test("小゛゜キーのフリック方向")
    func modifierFlick() {
        let h = TouchHarness()
        let m = h.center("modifier")
        h.stroke(1, from: m, through: [h.offset(m, 0, -30)])
        h.stroke(2, from: m)
        #expect(h.actions == [.modifier(.up), .modifier(.center)])
    }

    @Test("改行キーが無効なときは何もしない")
    func enterDisabled() {
        let h = TouchHarness()
        h.processor.isEnterDisabled = true
        h.stroke(1, from: h.center("enter"))
        #expect(h.actions.isEmpty)
        h.processor.isEnterDisabled = false
        h.stroke(2, from: h.center("enter"))
        #expect(h.actions == [.enter])
    }

    @Test("長押しでフリック先を十字に表示し、方向に動かすとその文字を強調する")
    func guide() {
        let h = TouchHarness()
        let a = h.center("a")
        h.processor.touchBegan(id: 1, at: a, time: 0)
        #expect(h.processor.visual.guide == nil)
        h.processor.tick(time: 0.4)
        #expect(h.processor.visual.guide?.showsAll == true)
        h.processor.touchMoved(id: 1, to: h.offset(a, -30, 0), time: 0.5)
        #expect(h.processor.visual.guide?.active == .left)
        h.processor.touchEnded(id: 1, at: h.offset(a, -30, 0), time: 0.6)
        #expect(h.processor.visual.guide == nil)
        #expect(h.flickOutputs == ["い"])
    }

    @Test("押している間だけ押下表示になる")
    func pressedState() {
        let h = TouchHarness()
        h.processor.touchBegan(id: 1, at: h.center("ta"), time: 0)
        #expect(h.processor.visual.pressedKeyIDs == ["ta"])
        h.processor.touchEnded(id: 1, at: h.center("ta"), time: 0.1)
        #expect(h.processor.visual.pressedKeyIDs.isEmpty)
    }

    @Test("キーの隙間を押しても最寄りのキーが反応する")
    func gapTap() {
        let h = TouchHarness()
        let a = h.geometry.keys.first { $0.definition.id == "a" }!.frame
        let ka = h.geometry.keys.first { $0.definition.id == "ka" }!.frame
        let gap = CGPoint(x: (a.maxX + ka.minX) / 2 - 0.5, y: a.midY)
        h.stroke(1, from: gap)
        #expect(h.flickOutputs == ["あ"])
    }

    @Test("◀キーの長押しで連続してカーソルを動かす")
    func cursorRepeat() {
        let h = TouchHarness()
        h.processor.touchBegan(id: 1, at: h.center("cursorLeft"), time: 0)
        h.processor.tick(time: 0.3)
        h.processor.tick(time: 0.41)
        h.processor.tick(time: 0.49)
        h.processor.touchEnded(id: 1, at: h.center("cursorLeft"), time: 0.5)
        #expect(h.actions == [.cursorLeft, .cursorLeft, .cursorLeft])
    }
}
