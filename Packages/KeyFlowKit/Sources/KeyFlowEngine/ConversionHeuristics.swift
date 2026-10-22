import Foundation

/// 辞書ベースの変換で起きやすい誤りを、点数が拮抗しているときだけ並べ替えて直す。
///
/// 学習済みの候補は点数差が大きくなるので、ここでの並べ替えが学習を上書きすることはない。
enum ConversionHeuristics {
    /// 1位と入れ替える候補との点数差の上限。これより差が大きければ変換エンジンの判断を優先する。
    /// （評価: 直したい「3次に→3時に」は差0.5〜0.95、崩したくない「2次の方程式」は差1.18。
    /// 少数の例から決めた値なので、評価用の文を増やしたら見直す）
    static let maximumScoreGap: Float = 1.0

    /// 1位の候補より望ましい表記があれば返す。
    ///
    /// - 半角数字の後の「次」で、後ろに漢字が続かないもの（「3次に」「10次」）→「時」
    ///   数字の後の「じ」はほとんどが時刻。半角数字のときだけ「次」に寄る傾向がある。
    ///   「3次元」「2次会」のように漢字が続くものは変えない。
    /// - 「第＋数字」の後の「時」で、後ろに漢字が続くもの（「第2時世界大戦」）→「次」
    static func preferredVariant(of text: String) -> String? {
        let chars = Array(text)
        var result = chars
        var changed = false
        for i in chars.indices {
            let previousIsDigit = i > 0 && chars[i - 1].isDigitLike
            guard previousIsDigit else { continue }
            let nextIsKanji = i + 1 < chars.count && chars[i + 1].isKanji
            // 直前の数字の並びの手前が「第」か
            var j = i - 1
            while j >= 0, chars[j].isDigitLike {
                j -= 1
            }
            let hasDaiPrefix = j >= 0 && chars[j] == "第"
            if chars[i] == "次", !nextIsKanji, !hasDaiPrefix {
                result[i] = "時"
                changed = true
            } else if chars[i] == "時", nextIsKanji, hasDaiPrefix {
                result[i] = "次"
                changed = true
            }
        }
        return changed ? String(result) : nil
    }

    /// 候補（点数の高い順）を必要なら並べ替えたものを返す
    static func reorder<T>(_ candidates: [T], text: (T) -> String, score: (T) -> Float) -> [T] {
        guard let top = candidates.first, let preferred = preferredVariant(of: text(top)),
              let index = candidates.firstIndex(where: { text($0) == preferred }), index > 0,
              score(top) - score(candidates[index]) < maximumScoreGap else {
            return candidates
        }
        var result = candidates
        let moved = result.remove(at: index)
        result.insert(moved, at: 0)
        return result
    }
}

extension Character {
    /// 半角・全角の数字
    var isDigitLike: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else { return false }
        return (0x30...0x39).contains(scalar.value) || (0xFF10...0xFF19).contains(scalar.value)
    }

    /// 漢字（CJK統合漢字と「々」）
    var isKanji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) || scalar.value == 0x3005
    }
}
