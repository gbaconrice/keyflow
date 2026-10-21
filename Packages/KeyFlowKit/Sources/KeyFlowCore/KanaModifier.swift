import Foundation

/// 濁点・半濁点・小文字の付け外し。
public enum KanaModifier {
    public enum Kind: Sendable {
        case dakuten
        case handakuten
        case small
    }

    private static let dakutenPairs: [(Character, Character)] = [
        ("か", "が"), ("き", "ぎ"), ("く", "ぐ"), ("け", "げ"), ("こ", "ご"),
        ("さ", "ざ"), ("し", "じ"), ("す", "ず"), ("せ", "ぜ"), ("そ", "ぞ"),
        ("た", "だ"), ("ち", "ぢ"), ("つ", "づ"), ("て", "で"), ("と", "ど"),
        ("は", "ば"), ("ひ", "び"), ("ふ", "ぶ"), ("へ", "べ"), ("ほ", "ぼ"),
        ("う", "ゔ"), ("ゝ", "ゞ"),
        ("カ", "ガ"), ("キ", "ギ"), ("ク", "グ"), ("ケ", "ゲ"), ("コ", "ゴ"),
        ("サ", "ザ"), ("シ", "ジ"), ("ス", "ズ"), ("セ", "ゼ"), ("ソ", "ゾ"),
        ("タ", "ダ"), ("チ", "ヂ"), ("ツ", "ヅ"), ("テ", "デ"), ("ト", "ド"),
        ("ハ", "バ"), ("ヒ", "ビ"), ("フ", "ブ"), ("ヘ", "ベ"), ("ホ", "ボ"),
        ("ウ", "ヴ"), ("ワ", "ヷ"), ("ヽ", "ヾ"),
    ]

    private static let handakutenPairs: [(Character, Character)] = [
        ("は", "ぱ"), ("ひ", "ぴ"), ("ふ", "ぷ"), ("へ", "ぺ"), ("ほ", "ぽ"),
        ("ハ", "パ"), ("ヒ", "ピ"), ("フ", "プ"), ("ヘ", "ペ"), ("ホ", "ポ"),
    ]

    private static let smallPairs: [(Character, Character)] = [
        ("あ", "ぁ"), ("い", "ぃ"), ("う", "ぅ"), ("え", "ぇ"), ("お", "ぉ"),
        ("つ", "っ"), ("や", "ゃ"), ("ゆ", "ゅ"), ("よ", "ょ"), ("わ", "ゎ"),
        ("か", "ゕ"), ("け", "ゖ"),
        ("ア", "ァ"), ("イ", "ィ"), ("ウ", "ゥ"), ("エ", "ェ"), ("オ", "ォ"),
        ("ツ", "ッ"), ("ヤ", "ャ"), ("ユ", "ュ"), ("ヨ", "ョ"), ("ワ", "ヮ"),
        ("カ", "ヵ"), ("ケ", "ヶ"),
    ]

    private static let dakutenMap = Dictionary(uniqueKeysWithValues: dakutenPairs)
    private static let dakutenReverse = Dictionary(uniqueKeysWithValues: dakutenPairs.map { ($1, $0) })
    private static let handakutenMap = Dictionary(uniqueKeysWithValues: handakutenPairs)
    private static let handakutenReverse = Dictionary(uniqueKeysWithValues: handakutenPairs.map { ($1, $0) })
    // 「か→ゕ」「け→ゖ」は小書き切替の巡回には含めない（日常の入力で邪魔になるため）
    private static let smallMap = Dictionary(uniqueKeysWithValues: smallPairs.filter { !"かけカケ".contains($0.0) })
    private static let smallReverse = Dictionary(uniqueKeysWithValues: smallPairs.map { ($1, $0) })

    /// 「小゛゜」キーをタップしたときの巡回。
    /// 例: か→が→か、は→ば→ぱ→は、つ→っ→づ→つ、う→ぅ→ゔ→う
    public static func cycle(_ c: Character) -> Character? {
        let base = baseForm(c)
        let sequence = cycleSequence(for: base)
        guard sequence.count > 1, let index = sequence.firstIndex(of: c) else {
            return nil
        }
        return sequence[(index + 1) % sequence.count]
    }

    /// 指定した修飾を付ける。すでに付いていれば外す。適用できない文字ならnil。
    public static func toggle(_ kind: Kind, on c: Character) -> Character? {
        let base = baseForm(c)
        let target: Character?
        switch kind {
        case .dakuten: target = dakutenMap[base]
        case .handakuten: target = handakutenMap[base]
        case .small: target = smallMap[base]
        }
        guard let target else {
            return nil
        }
        return c == target ? base : target
    }

    /// 修飾を外した文字
    public static func baseForm(_ c: Character) -> Character {
        dakutenReverse[c] ?? handakutenReverse[c] ?? smallReverse[c] ?? c
    }

    private static func cycleSequence(for base: Character) -> [Character] {
        var result: [Character] = [base]
        // 小書きを先にする（「つ→っ」が最もよく使われるため）
        if let small = smallMap[base] {
            result.append(small)
        }
        if let voiced = dakutenMap[base] {
            result.append(voiced)
        }
        if let semi = handakutenMap[base] {
            result.append(semi)
        }
        return result
    }
}
