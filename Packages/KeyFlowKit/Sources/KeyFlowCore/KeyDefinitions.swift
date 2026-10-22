import Foundation

/// キーボードの入力モード
public enum KeyboardMode: String, Codable, Sendable, CaseIterable {
    case kana
    case english
    case number
}

/// フリック入力キーの定義（中央＋4方向とタップ連打時の巡回）
public struct FlickKeySpec: Sendable, Equatable {
    public var label: String
    /// 方向ごとの出力。centerは必須。
    public var outputs: [FlickDirection: String]
    /// 同じキーを連打したときの巡回（トグル入力）。空ならトグルしない。
    public var toggleCycle: [String]
    /// キー上に小さく表示する補助ラベル（数字キーの記号など）
    public var subLabel: String?

    public init(label: String, outputs: [FlickDirection: String], toggleCycle: [String] = [], subLabel: String? = nil) {
        self.label = label
        self.outputs = outputs
        self.toggleCycle = toggleCycle
        self.subLabel = subLabel
    }

    /// 中央・左・上・右・下の順で指定する簡易初期化
    public static func kana(_ chars: [String], toggle extra: [String] = []) -> FlickKeySpec {
        var outputs: [FlickDirection: String] = [:]
        let directions: [FlickDirection] = [.center, .left, .up, .right, .down]
        for (direction, char) in zip(directions, chars) where !char.isEmpty {
            outputs[direction] = char
        }
        return FlickKeySpec(label: chars[0], outputs: outputs, toggleCycle: chars.filter { !$0.isEmpty } + extra)
    }

    public func output(for direction: FlickDirection) -> String? {
        outputs[direction]
    }
}

/// キーを押したときの動作
public enum KeyKind: Sendable, Equatable {
    /// フリック入力キー
    case flick(FlickKeySpec)
    /// 文字をそのまま入力する（QWERTYの文字キーなど）
    case character(String)
    /// 「小゛゜」キー
    case modifier
    case delete
    case space
    case enter
    case cursorLeft
    case cursorRight
    case shift
    case switchMode(KeyboardMode)
    /// 地球儀キー（ホームボタン搭載機など、システムが切替キーを出さない場合のみ表示）
    case nextKeyboard
    /// 直前の英字の大文字・小文字を切り替える（英字12キーの「a/A」）
    case caseToggle
}

/// 日本語の配列
public enum KanaLayout: String, Codable, Sendable, CaseIterable {
    /// 12キーのフリック
    case flick
    /// QWERTYのローマ字入力
    case romaji
}

/// 英字の配列
public enum EnglishLayout: String, Codable, Sendable, CaseIterable {
    case qwerty
    /// 12キーのフリック（標準キーボードの英字テンキーと同じ割り当て）
    case flick
}

/// キーの配置。グリッド上の列・行と幅・高さ（列数・行数）で表す。
public struct KeyPlacement: Sendable, Equatable {
    public var column: Double
    public var row: Int
    public var width: Double
    public var height: Int

    public init(column: Double, row: Int, width: Double = 1, height: Int = 1) {
        self.column = column
        self.row = row
        self.width = width
        self.height = height
    }
}

/// キー1つ分の定義
public struct KeyDefinition: Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: KeyKind
    public var placement: KeyPlacement
    /// 機能キー（色を変えて表示する）
    public var isFunctional: Bool

    public init(id: String, kind: KeyKind, placement: KeyPlacement, isFunctional: Bool = false) {
        self.id = id
        self.kind = kind
        self.placement = placement
        self.isFunctional = isFunctional
    }
}

/// 1つの入力モードのキー配列
public struct KeyboardLayoutSpec: Sendable, Equatable {
    public var mode: KeyboardMode
    /// 各列の相対幅。QWERTY系では行ごとの列数が異なるため`rowColumnCount`を使う。
    public var columnWeights: [Double]
    public var rowCount: Int
    public var keys: [KeyDefinition]
    /// QWERTY配列のように、行ごとに独立して横幅を割り当てる場合に使う
    public var isRowBased: Bool

    public init(mode: KeyboardMode, columnWeights: [Double], rowCount: Int, keys: [KeyDefinition], isRowBased: Bool = false) {
        self.mode = mode
        self.columnWeights = columnWeights
        self.rowCount = rowCount
        self.keys = keys
        self.isRowBased = isRowBased
    }
}

public enum KeyboardLayouts {
    /// 12キーのかな配列。
    ///
    /// ```
    /// [◀] [あ] [か] [さ]   [⌫]
    /// [▶] [た] [な] [は]   [空白]
    /// [ABC][ま] [や] [ら]   [改行]
    /// [123][小゛゜][わ][、。?!] [改行]
    /// ```
    public static func kana(showsGlobeKey: Bool, sideColumnWeight: Double = 0.86) -> KeyboardLayoutSpec {
        var keys: [KeyDefinition] = [
            .init(id: "cursorLeft", kind: .cursorLeft, placement: .init(column: 0, row: 0), isFunctional: true),
            .init(id: "cursorRight", kind: .cursorRight, placement: .init(column: 0, row: 1), isFunctional: true),
            .init(id: "a", kind: .flick(.kana(["あ", "い", "う", "え", "お"], toggle: ["ぁ", "ぃ", "ぅ", "ぇ", "ぉ"])), placement: .init(column: 1, row: 0)),
            .init(id: "ka", kind: .flick(.kana(["か", "き", "く", "け", "こ"])), placement: .init(column: 2, row: 0)),
            .init(id: "sa", kind: .flick(.kana(["さ", "し", "す", "せ", "そ"])), placement: .init(column: 3, row: 0)),
            .init(id: "ta", kind: .flick(.kana(["た", "ち", "つ", "て", "と"], toggle: ["っ"])), placement: .init(column: 1, row: 1)),
            .init(id: "na", kind: .flick(.kana(["な", "に", "ぬ", "ね", "の"])), placement: .init(column: 2, row: 1)),
            .init(id: "ha", kind: .flick(.kana(["は", "ひ", "ふ", "へ", "ほ"])), placement: .init(column: 3, row: 1)),
            .init(id: "ma", kind: .flick(.kana(["ま", "み", "む", "め", "も"])), placement: .init(column: 1, row: 2)),
            .init(id: "ya", kind: .flick(FlickKeySpec(
                label: "や",
                outputs: [.center: "や", .left: "「", .up: "ゆ", .right: "」", .down: "よ"],
                toggleCycle: ["や", "「", "ゆ", "」", "よ", "ゃ", "ゅ", "ょ"]
            )), placement: .init(column: 2, row: 2)),
            .init(id: "ra", kind: .flick(.kana(["ら", "り", "る", "れ", "ろ"])), placement: .init(column: 3, row: 2)),
            .init(id: "modifier", kind: .modifier, placement: .init(column: 1, row: 3)),
            .init(id: "wa", kind: .flick(FlickKeySpec(
                label: "わ",
                outputs: [.center: "わ", .left: "を", .up: "ん", .right: "ー"],
                toggleCycle: ["わ", "を", "ん", "ー", "ゎ"]
            )), placement: .init(column: 2, row: 3)),
            .init(id: "punct", kind: .flick(FlickKeySpec(
                label: "、。?!",
                outputs: [.center: "、", .left: "。", .up: "？", .right: "！", .down: "…"],
                toggleCycle: ["、", "。", "？", "！", "…"]
            )), placement: .init(column: 3, row: 3)),
            .init(id: "delete", kind: .delete, placement: .init(column: 4, row: 0), isFunctional: true),
            .init(id: "space", kind: .space, placement: .init(column: 4, row: 1), isFunctional: true),
            .init(id: "enter", kind: .enter, placement: .init(column: 4, row: 2, height: 2), isFunctional: true),
        ]
        keys.append(contentsOf: leftBottomKeys(current: .kana, showsGlobeKey: showsGlobeKey))
        return KeyboardLayoutSpec(
            mode: .kana,
            columnWeights: [sideColumnWeight, 1, 1, 1, sideColumnWeight],
            rowCount: 4,
            keys: keys
        )
    }

    /// 12キーの数字・記号配列
    public static func number(showsGlobeKey: Bool, sideColumnWeight: Double = 0.86) -> KeyboardLayoutSpec {
        func num(_ center: String, _ subs: [String], toggle: Bool = true) -> KeyKind {
            var outputs: [FlickDirection: String] = [.center: center]
            for (direction, s) in zip([FlickDirection.left, .up, .right, .down], subs) {
                outputs[direction] = s
            }
            return .flick(FlickKeySpec(label: center, outputs: outputs, toggleCycle: toggle ? [center] + subs : [], subLabel: subs.joined()))
        }
        var keys: [KeyDefinition] = [
            .init(id: "cursorLeft", kind: .cursorLeft, placement: .init(column: 0, row: 0), isFunctional: true),
            .init(id: "cursorRight", kind: .cursorRight, placement: .init(column: 0, row: 1), isFunctional: true),
            .init(id: "n1", kind: num("1", ["☆", "♪", "→"]), placement: .init(column: 1, row: 0)),
            .init(id: "n2", kind: num("2", ["¥", "$", "€"]), placement: .init(column: 2, row: 0)),
            .init(id: "n3", kind: num("3", ["%", "°", "#"]), placement: .init(column: 3, row: 0)),
            .init(id: "n4", kind: num("4", ["○", "＊", "・"]), placement: .init(column: 1, row: 1)),
            .init(id: "n5", kind: num("5", ["+", "×", "÷"]), placement: .init(column: 2, row: 1)),
            .init(id: "n6", kind: num("6", ["<", "=", ">"]), placement: .init(column: 3, row: 1)),
            .init(id: "n7", kind: num("7", ["「", "」", ":"]), placement: .init(column: 1, row: 2)),
            .init(id: "n8", kind: num("8", ["〒", "々", "〆"]), placement: .init(column: 2, row: 2)),
            .init(id: "n9", kind: num("9", ["^", "|", "\\"]), placement: .init(column: 3, row: 2)),
            .init(id: "paren", kind: .flick(FlickKeySpec(
                label: "()[]",
                outputs: [.center: "(", .left: ")", .up: "[", .right: "]"],
                toggleCycle: ["(", ")", "[", "]"]
            )), placement: .init(column: 1, row: 3)),
            .init(id: "n0", kind: num("0", ["〜", "…"]), placement: .init(column: 2, row: 3)),
            .init(id: "dot", kind: .flick(FlickKeySpec(
                label: ".,-/",
                outputs: [.center: ".", .left: ",", .up: "-", .right: "/", .down: "@"],
                toggleCycle: [".", ",", "-", "/", "@"]
            )), placement: .init(column: 3, row: 3)),
            .init(id: "delete", kind: .delete, placement: .init(column: 4, row: 0), isFunctional: true),
            .init(id: "space", kind: .space, placement: .init(column: 4, row: 1), isFunctional: true),
            .init(id: "enter", kind: .enter, placement: .init(column: 4, row: 2, height: 2), isFunctional: true),
        ]
        keys.append(contentsOf: leftBottomKeys(current: .number, showsGlobeKey: showsGlobeKey))
        return KeyboardLayoutSpec(
            mode: .number,
            columnWeights: [sideColumnWeight, 1, 1, 1, sideColumnWeight],
            rowCount: 4,
            keys: keys
        )
    }

    /// 英字QWERTY配列
    public static func english(showsGlobeKey: Bool) -> KeyboardLayoutSpec {
        var keys: [KeyDefinition] = []
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for (r, letters) in rows.enumerated() {
            let offset: Double = r == 1 ? 0.5 : (r == 2 ? 1.5 : 0)
            for (i, letter) in letters.enumerated() {
                keys.append(.init(id: "en_\(letter)", kind: .character(String(letter)), placement: .init(column: offset + Double(i), row: r)))
            }
        }
        keys.append(.init(id: "shift", kind: .shift, placement: .init(column: 0, row: 2, width: 1.3), isFunctional: true))
        keys.append(.init(id: "delete", kind: .delete, placement: .init(column: 8.7, row: 2, width: 1.3), isFunctional: true))
        // 下段: [123][あいう][🌐?][, ][  space  ][. ][改行]
        var column: Double = 0
        keys.append(.init(id: "toNumber", kind: .switchMode(.number), placement: .init(column: column, row: 3, width: 1.25), isFunctional: true))
        column += 1.25
        keys.append(.init(id: "toKana", kind: .switchMode(.kana), placement: .init(column: column, row: 3, width: 1.25), isFunctional: true))
        column += 1.25
        if showsGlobeKey {
            keys.append(.init(id: "globe", kind: .nextKeyboard, placement: .init(column: column, row: 3, width: 1), isFunctional: true))
            column += 1
        }
        keys.append(.init(id: "comma", kind: .character(","), placement: .init(column: column, row: 3, width: 0.8)))
        column += 0.8
        let spaceWidth = 10 - column - 0.8 - 2.0
        keys.append(.init(id: "space", kind: .space, placement: .init(column: column, row: 3, width: spaceWidth)))
        column += spaceWidth
        keys.append(.init(id: "period", kind: .character("."), placement: .init(column: column, row: 3, width: 0.8)))
        column += 0.8
        keys.append(.init(id: "enter", kind: .enter, placement: .init(column: column, row: 3, width: 2.0), isFunctional: true))
        return KeyboardLayoutSpec(mode: .english, columnWeights: Array(repeating: 1, count: 10), rowCount: 4, keys: keys, isRowBased: true)
    }

    /// ローマ字入力のQWERTY配列
    ///
    /// ```
    /// [q][w][e][r][t][y][u][i][o][p]
    /// [a][s][d][f][g][h][j][k][l][ー]
    /// [⇧] [z][x][c][v][b][n][m] [⌫]
    /// [☆123][ABC][、][  空白  ][。][改行]
    /// ```
    public static func romaji(showsGlobeKey: Bool) -> KeyboardLayoutSpec {
        var keys: [KeyDefinition] = []
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for (r, letters) in rows.enumerated() {
            let offset: Double = r == 2 ? 1.5 : 0
            for (i, letter) in letters.enumerated() {
                keys.append(.init(id: "ro_\(letter)", kind: .character(String(letter)), placement: .init(column: offset + Double(i), row: r)))
            }
        }
        keys.append(.init(id: "ro_long", kind: .character("ー"), placement: .init(column: 9, row: 1)))
        keys.append(.init(id: "shift", kind: .shift, placement: .init(column: 0, row: 2, width: 1.3), isFunctional: true))
        keys.append(.init(id: "delete", kind: .delete, placement: .init(column: 8.7, row: 2, width: 1.3), isFunctional: true))
        var column: Double = 0
        keys.append(.init(id: "toNumber", kind: .switchMode(.number), placement: .init(column: column, row: 3, width: 1.25), isFunctional: true))
        column += 1.25
        keys.append(.init(id: "toEnglish", kind: .switchMode(.english), placement: .init(column: column, row: 3, width: 1.25), isFunctional: true))
        column += 1.25
        if showsGlobeKey {
            keys.append(.init(id: "globe", kind: .nextKeyboard, placement: .init(column: column, row: 3, width: 1), isFunctional: true))
            column += 1
        }
        // 、。は上フリックで？！も入れられる
        keys.append(.init(id: "ro_comma", kind: .flick(FlickKeySpec(label: "、", outputs: [.center: "、", .up: "？"], subLabel: "？")), placement: .init(column: column, row: 3, width: 1)))
        column += 1
        let spaceWidth = 10 - column - 1 - 2.0
        keys.append(.init(id: "space", kind: .space, placement: .init(column: column, row: 3, width: spaceWidth)))
        column += spaceWidth
        keys.append(.init(id: "ro_period", kind: .flick(FlickKeySpec(label: "。", outputs: [.center: "。", .up: "！"], subLabel: "！")), placement: .init(column: column, row: 3, width: 1)))
        column += 1
        keys.append(.init(id: "enter", kind: .enter, placement: .init(column: column, row: 3, width: 2.0), isFunctional: true))
        return KeyboardLayoutSpec(mode: .kana, columnWeights: Array(repeating: 1, count: 10), rowCount: 4, keys: keys, isRowBased: true)
    }

    /// 12キー配列の左下2キー（モード切替と地球儀）
    private static func leftBottomKeys(current: KeyboardMode, showsGlobeKey: Bool) -> [KeyDefinition] {
        let other: KeyboardMode = current == .kana ? .number : .kana
        if showsGlobeKey {
            // 地球儀キーが必要な機種では、英字・数字/かなの切替を1キーにまとめる
            return [
                .init(id: "modeCycle", kind: .switchMode(current == .kana ? .english : .kana), placement: .init(column: 0, row: 2), isFunctional: true),
                .init(id: "globe", kind: .nextKeyboard, placement: .init(column: 0, row: 3), isFunctional: true),
            ]
        }
        return [
            .init(id: "toEnglish", kind: .switchMode(.english), placement: .init(column: 0, row: 2), isFunctional: true),
            .init(id: "toOther", kind: .switchMode(other), placement: .init(column: 0, row: 3), isFunctional: true),
        ]
    }

    /// 英字の12キー配列
    ///
    /// ```
    /// [◀] [@#/&_] [ABC] [DEF]    [⌫]
    /// [▶] [GHI]   [JKL] [MNO]    [space]
    /// [あいう][PQRS] [TUV] [WXYZ]  [改行]
    /// [123][a/A]  ['"()] [.,?!] [改行]
    /// ```
    public static func englishFlick(showsGlobeKey: Bool, sideColumnWeight: Double = 0.86) -> KeyboardLayoutSpec {
        func letters(_ chars: [String]) -> KeyKind {
            var outputs: [FlickDirection: String] = [:]
            for (direction, c) in zip([FlickDirection.center, .left, .up, .right, .down], chars) {
                outputs[direction] = c
            }
            return .flick(FlickKeySpec(label: chars.joined().uppercased(), outputs: outputs, toggleCycle: chars))
        }
        var keys: [KeyDefinition] = [
            .init(id: "cursorLeft", kind: .cursorLeft, placement: .init(column: 0, row: 0), isFunctional: true),
            .init(id: "cursorRight", kind: .cursorRight, placement: .init(column: 0, row: 1), isFunctional: true),
            .init(id: "e_at", kind: .flick(FlickKeySpec(label: "@#/&_", outputs: [.center: "@", .left: "#", .up: "/", .right: "&", .down: "_"], toggleCycle: ["@", "#", "/", "&", "_"])), placement: .init(column: 1, row: 0)),
            .init(id: "e_abc", kind: letters(["a", "b", "c"]), placement: .init(column: 2, row: 0)),
            .init(id: "e_def", kind: letters(["d", "e", "f"]), placement: .init(column: 3, row: 0)),
            .init(id: "e_ghi", kind: letters(["g", "h", "i"]), placement: .init(column: 1, row: 1)),
            .init(id: "e_jkl", kind: letters(["j", "k", "l"]), placement: .init(column: 2, row: 1)),
            .init(id: "e_mno", kind: letters(["m", "n", "o"]), placement: .init(column: 3, row: 1)),
            .init(id: "e_pqrs", kind: letters(["p", "q", "r", "s"]), placement: .init(column: 1, row: 2)),
            .init(id: "e_tuv", kind: letters(["t", "u", "v"]), placement: .init(column: 2, row: 2)),
            .init(id: "e_wxyz", kind: letters(["w", "x", "y", "z"]), placement: .init(column: 3, row: 2)),
            .init(id: "caseToggle", kind: .caseToggle, placement: .init(column: 1, row: 3)),
            .init(id: "e_quote", kind: .flick(FlickKeySpec(label: "'\"()", outputs: [.center: "'", .left: "\"", .up: "(", .right: ")"], toggleCycle: ["'", "\"", "(", ")"])), placement: .init(column: 2, row: 3)),
            .init(id: "e_punct", kind: .flick(FlickKeySpec(label: ".,?!", outputs: [.center: ".", .left: ",", .up: "?", .right: "!"], toggleCycle: [".", ",", "?", "!"])), placement: .init(column: 3, row: 3)),
            .init(id: "delete", kind: .delete, placement: .init(column: 4, row: 0), isFunctional: true),
            .init(id: "space", kind: .space, placement: .init(column: 4, row: 1), isFunctional: true),
            .init(id: "enter", kind: .enter, placement: .init(column: 4, row: 2, height: 2), isFunctional: true),
        ]
        if showsGlobeKey {
            keys.append(.init(id: "modeCycle", kind: .switchMode(.number), placement: .init(column: 0, row: 2), isFunctional: true))
            keys.append(.init(id: "globe", kind: .nextKeyboard, placement: .init(column: 0, row: 3), isFunctional: true))
        } else {
            keys.append(.init(id: "toKana", kind: .switchMode(.kana), placement: .init(column: 0, row: 2), isFunctional: true))
            keys.append(.init(id: "toNumber", kind: .switchMode(.number), placement: .init(column: 0, row: 3), isFunctional: true))
        }
        return KeyboardLayoutSpec(mode: .english, columnWeights: [sideColumnWeight, 1, 1, 1, sideColumnWeight], rowCount: 4, keys: keys)
    }

    public static func layout(for mode: KeyboardMode, showsGlobeKey: Bool, kanaLayout: KanaLayout = .flick, englishLayout: EnglishLayout = .qwerty, sideColumnWeight: Double = 0.86) -> KeyboardLayoutSpec {
        switch mode {
        case .kana:
            switch kanaLayout {
            case .flick: return kana(showsGlobeKey: showsGlobeKey, sideColumnWeight: sideColumnWeight)
            case .romaji: return romaji(showsGlobeKey: showsGlobeKey)
            }
        case .number: return number(showsGlobeKey: showsGlobeKey, sideColumnWeight: sideColumnWeight)
        case .english:
            switch englishLayout {
            case .qwerty: return english(showsGlobeKey: showsGlobeKey)
            case .flick: return englishFlick(showsGlobeKey: showsGlobeKey, sideColumnWeight: sideColumnWeight)
            }
        }
    }
}
