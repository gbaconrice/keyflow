import Foundation

/// フリックの方向。`center`はタップ（移動量がしきい値未満）を表す。
public enum FlickDirection: Int, CaseIterable, Codable, Sendable {
    case center
    case left
    case up
    case right
    case down
}

/// タッチの移動量からフリック方向を判定する。
///
/// UIKitに依存しない純粋な計算にしてあり、しきい値や判定の偏りをテストで検証できる。
public struct FlickClassifier: Sendable, Equatable {
    /// フリックとみなす最小移動距離（pt）
    public var threshold: Double
    /// 上下方向の判定を広げる係数。1.0で45°ずつ均等。
    /// 親指の横移動は大きくなりやすく、上下フリックが左右に誤判定されやすいため、既定値で上下をわずかに広げる。
    public var verticalBias: Double

    public init(threshold: Double = 20, verticalBias: Double = 1.15) {
        self.threshold = threshold
        self.verticalBias = verticalBias
    }

    /// - Parameters:
    ///   - dx: 右方向が正
    ///   - dy: 下方向が正（UIKitの座標系）
    public func direction(dx: Double, dy: Double) -> FlickDirection {
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= threshold else {
            return .center
        }
        if abs(dy) * verticalBias >= abs(dx) {
            return dy < 0 ? .up : .down
        } else {
            return dx < 0 ? .left : .right
        }
    }
}
