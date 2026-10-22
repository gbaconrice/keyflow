import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// レイアウト計算の入力
public struct LayoutContext: Sendable, Equatable {
    /// キーボード全体の幅（pt）
    public var width: Double
    /// 横画面か
    public var isLandscape: Bool
    public var settings: KeyboardSettings

    public init(width: Double, isLandscape: Bool, settings: KeyboardSettings) {
        self.width = width
        self.isLandscape = isLandscape
        self.settings = settings
    }

    /// 候補バーを除くキー領域の高さ
    public var keyAreaHeight: Double {
        isLandscape ? settings.landscapeKeyAreaHeight : settings.portraitKeyAreaHeight
    }

    /// キーボード全体の高さ（候補バーを含む）
    public var totalHeight: Double {
        keyAreaHeight + settings.candidateBarHeight
    }
}

/// 計算済みのキー
public struct LaidOutKey: Sendable, Equatable {
    public var definition: KeyDefinition
    /// 見た目の矩形（キー領域内の座標）
    public var frame: CGRect
    /// タッチ判定の矩形。キー間の隙間を埋めるように広げてあり、隙間をタップしても最寄りのキーが反応する。
    public var hitFrame: CGRect
}

public struct KeyboardGeometry: Sendable, Equatable {
    /// キー領域全体の大きさ
    public var size: CGSize
    /// キーを並べる範囲（片手モードや横画面で狭くなる）
    public var contentFrame: CGRect
    public var keys: [LaidOutKey]

    /// 座標からキーを探す。どのキーの判定範囲にも入らない場合は最も近いキーを返す。
    public func key(at point: CGPoint) -> LaidOutKey? {
        if let hit = keys.first(where: { $0.hitFrame.contains(point) }) {
            return hit
        }
        guard contentFrame.insetBy(dx: -24, dy: -24).contains(point) else {
            return nil
        }
        return keys.min { distance(point, $0.frame) < distance(point, $1.frame) }
    }

    private func distance(_ p: CGPoint, _ r: CGRect) -> Double {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return Double(dx * dx + dy * dy)
    }
}

public enum LayoutEngine {
    /// キー配列と設定から各キーの矩形を計算する
    public static func layout(_ spec: KeyboardLayoutSpec, context: LayoutContext) -> KeyboardGeometry {
        let s = context.settings
        let height = context.keyAreaHeight
        let size = CGSize(width: context.width, height: height)

        // キーを並べる幅（片手モード・横画面）
        var contentWidth = context.width - s.sideMargin * 2
        var contentX = s.sideMargin
        if context.isLandscape {
            let w = context.width * s.landscapeWidthRatio
            contentX = (context.width - w) / 2 + s.sideMargin
            contentWidth = w - s.sideMargin * 2
        } else if s.oneHandedMode != .off {
            let w = context.width * s.oneHandedWidthRatio
            contentWidth = w - s.sideMargin * 2
            contentX = s.oneHandedMode == .left ? s.sideMargin : context.width - w + s.sideMargin
        }
        let contentHeight = height - s.bottomMargin
        let contentFrame = CGRect(x: contentX, y: 0, width: max(contentWidth, 1), height: max(contentHeight, 1))

        let hGap = s.horizontalKeySpacing
        let vGap = s.verticalKeySpacing
        let rows = spec.rowCount
        // 上端は候補バーとの間に半分の隙間を空ける
        let topInset = vGap / 2
        let rowHeight = (contentFrame.height - topInset - vGap * Double(rows - 1)) / Double(rows)

        // 列の左端位置（12キー配列は列ごとの重みで分配）
        let weights: [Double]
        if spec.isRowBased {
            weights = spec.columnWeights
        } else {
            var w = spec.columnWeights
            if w.count == 5 {
                w[0] = s.sideColumnRatio
                w[4] = s.sideColumnRatio
            }
            weights = w
        }
        let totalWeight = weights.reduce(0, +)
        let columnUnit = (contentFrame.width + hGap) / totalWeight
        func columnX(_ column: Double) -> Double {
            // 小数の列位置（QWERTYのずらし）にも対応するため、整数部分を重み付きで、端数を単位幅で足す
            let whole = Int(column)
            var x: Double = 0
            for i in 0..<min(whole, weights.count) {
                x += weights[i] * columnUnit
            }
            let frac = column - Double(whole)
            if frac > 0 {
                x += frac * (whole < weights.count ? weights[whole] : 1) * columnUnit
            }
            return contentFrame.minX + x
        }
        func columnSpanWidth(_ column: Double, _ width: Double) -> Double {
            columnX(column + width) - columnX(column) - hGap
        }

        var laidOut: [LaidOutKey] = []
        for key in spec.keys {
            let p = key.placement
            let x = columnX(p.column)
            let w = columnSpanWidth(p.column, p.width)
            let y = topInset + Double(p.row) * (rowHeight + vGap)
            let h = rowHeight * Double(p.height) + vGap * Double(p.height - 1)
            let frame = CGRect(x: x, y: y, width: max(w, 1), height: max(h, 1))
            laidOut.append(LaidOutKey(definition: key, frame: frame, hitFrame: frame))
        }

        // 判定範囲を隙間の半分ずつ広げる。外周のキーは端まで広げる。
        let minX = laidOut.map(\.frame.minX).min() ?? 0
        let maxX = laidOut.map(\.frame.maxX).max() ?? 0
        let minY = laidOut.map(\.frame.minY).min() ?? 0
        let maxY = laidOut.map(\.frame.maxY).max() ?? 0
        for i in laidOut.indices {
            let f = laidOut[i].frame
            var left = f.minX - hGap / 2
            var right = f.maxX + hGap / 2
            var top = f.minY - vGap / 2
            var bottom = f.maxY + vGap / 2
            if abs(f.minX - minX) < 0.5 { left = context.isLandscape || s.oneHandedMode != .off ? f.minX - s.sideMargin : 0 }
            if abs(f.maxX - maxX) < 0.5 { right = context.isLandscape || s.oneHandedMode != .off ? f.maxX + s.sideMargin : context.width }
            if abs(f.minY - minY) < 0.5 { top = 0 }
            if abs(f.maxY - maxY) < 0.5 { bottom = height }
            laidOut[i].hitFrame = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        }

        return KeyboardGeometry(size: size, contentFrame: contentFrame, keys: laidOut)
    }
}
