import Foundation

/// 片手モード
public enum OneHandedMode: String, Codable, Sendable, CaseIterable {
    case off
    case left
    case right
}

/// 空白キーで入れる文字
public enum SpaceWidth: String, Codable, Sendable, CaseIterable {
    case half
    case full
}

/// キーボードの設定値。
///
/// 値の範囲は`ranges`で一元管理し、読み込み時に`normalized()`で丸める。
/// 古い設定データに無いキーは既定値で補う（`init(from:)`参照）。
public struct KeyboardSettings: Codable, Sendable, Equatable {
    // MARK: サイズ・配置

    /// 縦画面時のキー領域の高さ（候補バーを除く, pt）
    public var portraitKeyAreaHeight: Double = 236
    /// 横画面時のキー領域の高さ（pt）
    public var landscapeKeyAreaHeight: Double = 160
    /// 候補バーの高さ（pt）
    public var candidateBarHeight: Double = 42
    /// キーどうしの横の間隔（pt）
    public var horizontalKeySpacing: Double = 6
    /// キーどうしの縦の間隔（pt）
    public var verticalKeySpacing: Double = 7
    /// キーボード左右の余白（pt）
    public var sideMargin: Double = 4
    /// キーボード下端の余白（pt）
    public var bottomMargin: Double = 4
    /// 12キー配列の左右の機能キー列の幅（中央列に対する比率）
    public var sideColumnRatio: Double = 0.86
    /// 片手モード
    public var oneHandedMode: OneHandedMode = .off
    /// 片手モード時のキーボード幅（画面幅に対する比率）
    public var oneHandedWidthRatio: Double = 0.82
    /// 横画面のとき左右に寄せずに中央の幅を絞る比率（1.0で全幅）
    public var landscapeWidthRatio: Double = 0.78
    /// キーの角丸（pt）
    public var keyCornerRadius: Double = 7
    /// かなキーの文字サイズ（pt）
    public var kanaFontSize: Double = 22
    /// 候補の文字サイズ（pt）
    public var candidateFontSize: Double = 17

    // MARK: 入力

    /// フリックとみなす移動距離（pt）
    public var flickThreshold: Double = 20
    /// 同じキーの連打で文字を切り替える（トグル入力）
    public var toggleInputEnabled: Bool = true
    /// トグル入力を確定するまでの時間（秒）。0なら時間では確定しない。
    public var toggleTimeout: Double = 0
    /// 押下中にフリック先の文字を表示する
    public var showsFlickGuide: Bool = true
    /// キーの上下左右にフリック先の文字を小さく表示する
    public var showsKeyHints: Bool = false
    /// 空白キーで入れるスペース
    public var spaceWidth: SpaceWidth = .half
    /// 入力中の文字列に下線を付けて表示する（marked text）。
    /// 無効にすると、入力中の文字を通常の文字として挿入・置換する。
    public var usesMarkedText: Bool = true
    /// 英字入力で文頭を大文字にする
    public var englishAutoCapitalization: Bool = false
    /// 削除キー長押しの連続削除が始まるまでの時間（秒）
    public var deleteRepeatDelay: Double = 0.45
    /// 空白キーを横にドラッグしたときのカーソル移動1文字あたりの距離（pt）
    public var cursorDragStep: Double = 11

    // MARK: フィードバック

    /// 押下時の振動（フルアクセスが必要）
    public var hapticFeedback: Bool = true
    /// 押下時のクリック音（iOSの「キーボードのクリック」設定に従う）
    public var keySound: Bool = false

    // MARK: 変換・学習

    /// 確定した候補を学習する
    public var learningEnabled: Bool = true
    /// 予測変換（入力途中で続きを候補に出す）
    public var predictionEnabled: Bool = true
    /// 確定後に次の語を予測する
    public var nextWordPredictionEnabled: Bool = true
    /// 絵文字を候補に含める
    public var emojiCandidates: Bool = true
    /// テキストを選択したときに変換し直す候補を出す
    public var reconversionEnabled: Bool = true

    /// 設定を最後に変更した時刻（アプリとキーボード内で変更した値のどちらが新しいかの判定に使う）
    public var updatedAt: Date = .distantPast

    public init() {}

    public static let `default` = KeyboardSettings()

    /// 調整可能な範囲
    public enum Ranges {
        public static let portraitKeyAreaHeight: ClosedRange<Double> = 170...340
        public static let landscapeKeyAreaHeight: ClosedRange<Double> = 110...240
        public static let candidateBarHeight: ClosedRange<Double> = 32...56
        public static let horizontalKeySpacing: ClosedRange<Double> = 0...16
        public static let verticalKeySpacing: ClosedRange<Double> = 0...16
        public static let sideMargin: ClosedRange<Double> = 0...40
        public static let bottomMargin: ClosedRange<Double> = 0...40
        public static let sideColumnRatio: ClosedRange<Double> = 0.6...1.2
        public static let oneHandedWidthRatio: ClosedRange<Double> = 0.6...0.95
        public static let landscapeWidthRatio: ClosedRange<Double> = 0.5...1.0
        public static let keyCornerRadius: ClosedRange<Double> = 0...16
        public static let kanaFontSize: ClosedRange<Double> = 14...30
        public static let candidateFontSize: ClosedRange<Double> = 13...24
        public static let flickThreshold: ClosedRange<Double> = 8...45
        public static let toggleTimeout: ClosedRange<Double> = 0...2
        public static let deleteRepeatDelay: ClosedRange<Double> = 0.2...1.0
        public static let cursorDragStep: ClosedRange<Double> = 5...30
    }

    /// 範囲外の値を丸めた設定
    public func normalized() -> KeyboardSettings {
        var s = self
        s.portraitKeyAreaHeight = s.portraitKeyAreaHeight.clamped(to: Ranges.portraitKeyAreaHeight)
        s.landscapeKeyAreaHeight = s.landscapeKeyAreaHeight.clamped(to: Ranges.landscapeKeyAreaHeight)
        s.candidateBarHeight = s.candidateBarHeight.clamped(to: Ranges.candidateBarHeight)
        s.horizontalKeySpacing = s.horizontalKeySpacing.clamped(to: Ranges.horizontalKeySpacing)
        s.verticalKeySpacing = s.verticalKeySpacing.clamped(to: Ranges.verticalKeySpacing)
        s.sideMargin = s.sideMargin.clamped(to: Ranges.sideMargin)
        s.bottomMargin = s.bottomMargin.clamped(to: Ranges.bottomMargin)
        s.sideColumnRatio = s.sideColumnRatio.clamped(to: Ranges.sideColumnRatio)
        s.oneHandedWidthRatio = s.oneHandedWidthRatio.clamped(to: Ranges.oneHandedWidthRatio)
        s.landscapeWidthRatio = s.landscapeWidthRatio.clamped(to: Ranges.landscapeWidthRatio)
        s.keyCornerRadius = s.keyCornerRadius.clamped(to: Ranges.keyCornerRadius)
        s.kanaFontSize = s.kanaFontSize.clamped(to: Ranges.kanaFontSize)
        s.candidateFontSize = s.candidateFontSize.clamped(to: Ranges.candidateFontSize)
        s.flickThreshold = s.flickThreshold.clamped(to: Ranges.flickThreshold)
        s.toggleTimeout = s.toggleTimeout.clamped(to: Ranges.toggleTimeout)
        s.deleteRepeatDelay = s.deleteRepeatDelay.clamped(to: Ranges.deleteRepeatDelay)
        s.cursorDragStep = s.cursorDragStep.clamped(to: Ranges.cursorDragStep)
        return s
    }

    // MARK: Codable（欠けたキーは既定値で補う）

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case portraitKeyAreaHeight, landscapeKeyAreaHeight, candidateBarHeight
        case horizontalKeySpacing, verticalKeySpacing, sideMargin, bottomMargin, sideColumnRatio
        case oneHandedMode, oneHandedWidthRatio, landscapeWidthRatio, keyCornerRadius, kanaFontSize, candidateFontSize
        case flickThreshold, toggleInputEnabled, toggleTimeout, showsFlickGuide, showsKeyHints, spaceWidth, usesMarkedText
        case englishAutoCapitalization, deleteRepeatDelay, cursorDragStep
        case hapticFeedback, keySound
        case learningEnabled, predictionEnabled, nextWordPredictionEnabled, emojiCandidates, reconversionEnabled
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        portraitKeyAreaHeight = v(.portraitKeyAreaHeight, d.portraitKeyAreaHeight)
        landscapeKeyAreaHeight = v(.landscapeKeyAreaHeight, d.landscapeKeyAreaHeight)
        candidateBarHeight = v(.candidateBarHeight, d.candidateBarHeight)
        horizontalKeySpacing = v(.horizontalKeySpacing, d.horizontalKeySpacing)
        verticalKeySpacing = v(.verticalKeySpacing, d.verticalKeySpacing)
        sideMargin = v(.sideMargin, d.sideMargin)
        bottomMargin = v(.bottomMargin, d.bottomMargin)
        sideColumnRatio = v(.sideColumnRatio, d.sideColumnRatio)
        oneHandedMode = v(.oneHandedMode, d.oneHandedMode)
        oneHandedWidthRatio = v(.oneHandedWidthRatio, d.oneHandedWidthRatio)
        landscapeWidthRatio = v(.landscapeWidthRatio, d.landscapeWidthRatio)
        keyCornerRadius = v(.keyCornerRadius, d.keyCornerRadius)
        kanaFontSize = v(.kanaFontSize, d.kanaFontSize)
        candidateFontSize = v(.candidateFontSize, d.candidateFontSize)
        flickThreshold = v(.flickThreshold, d.flickThreshold)
        toggleInputEnabled = v(.toggleInputEnabled, d.toggleInputEnabled)
        toggleTimeout = v(.toggleTimeout, d.toggleTimeout)
        showsFlickGuide = v(.showsFlickGuide, d.showsFlickGuide)
        showsKeyHints = v(.showsKeyHints, d.showsKeyHints)
        spaceWidth = v(.spaceWidth, d.spaceWidth)
        usesMarkedText = v(.usesMarkedText, d.usesMarkedText)
        englishAutoCapitalization = v(.englishAutoCapitalization, d.englishAutoCapitalization)
        deleteRepeatDelay = v(.deleteRepeatDelay, d.deleteRepeatDelay)
        cursorDragStep = v(.cursorDragStep, d.cursorDragStep)
        hapticFeedback = v(.hapticFeedback, d.hapticFeedback)
        keySound = v(.keySound, d.keySound)
        learningEnabled = v(.learningEnabled, d.learningEnabled)
        predictionEnabled = v(.predictionEnabled, d.predictionEnabled)
        nextWordPredictionEnabled = v(.nextWordPredictionEnabled, d.nextWordPredictionEnabled)
        emojiCandidates = v(.emojiCandidates, d.emojiCandidates)
        reconversionEnabled = v(.reconversionEnabled, d.reconversionEnabled)
        updatedAt = v(.updatedAt, d.updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(portraitKeyAreaHeight, forKey: .portraitKeyAreaHeight)
        try c.encode(landscapeKeyAreaHeight, forKey: .landscapeKeyAreaHeight)
        try c.encode(candidateBarHeight, forKey: .candidateBarHeight)
        try c.encode(horizontalKeySpacing, forKey: .horizontalKeySpacing)
        try c.encode(verticalKeySpacing, forKey: .verticalKeySpacing)
        try c.encode(sideMargin, forKey: .sideMargin)
        try c.encode(bottomMargin, forKey: .bottomMargin)
        try c.encode(sideColumnRatio, forKey: .sideColumnRatio)
        try c.encode(oneHandedMode, forKey: .oneHandedMode)
        try c.encode(oneHandedWidthRatio, forKey: .oneHandedWidthRatio)
        try c.encode(landscapeWidthRatio, forKey: .landscapeWidthRatio)
        try c.encode(keyCornerRadius, forKey: .keyCornerRadius)
        try c.encode(kanaFontSize, forKey: .kanaFontSize)
        try c.encode(candidateFontSize, forKey: .candidateFontSize)
        try c.encode(flickThreshold, forKey: .flickThreshold)
        try c.encode(toggleInputEnabled, forKey: .toggleInputEnabled)
        try c.encode(toggleTimeout, forKey: .toggleTimeout)
        try c.encode(showsFlickGuide, forKey: .showsFlickGuide)
        try c.encode(showsKeyHints, forKey: .showsKeyHints)
        try c.encode(spaceWidth, forKey: .spaceWidth)
        try c.encode(usesMarkedText, forKey: .usesMarkedText)
        try c.encode(englishAutoCapitalization, forKey: .englishAutoCapitalization)
        try c.encode(deleteRepeatDelay, forKey: .deleteRepeatDelay)
        try c.encode(cursorDragStep, forKey: .cursorDragStep)
        try c.encode(hapticFeedback, forKey: .hapticFeedback)
        try c.encode(keySound, forKey: .keySound)
        try c.encode(learningEnabled, forKey: .learningEnabled)
        try c.encode(predictionEnabled, forKey: .predictionEnabled)
        try c.encode(nextWordPredictionEnabled, forKey: .nextWordPredictionEnabled)
        try c.encode(emojiCandidates, forKey: .emojiCandidates)
        try c.encode(reconversionEnabled, forKey: .reconversionEnabled)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
