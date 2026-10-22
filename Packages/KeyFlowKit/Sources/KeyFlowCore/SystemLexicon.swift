import Foundation

/// iPhoneの「ユーザ辞書」（設定 → 一般 → キーボード → ユーザ辞書）の単語を変換に使う。
///
/// キーボード拡張は`requestSupplementaryLexicon`で、フルアクセスがなくても読める（Appleの説明による）。
/// 読める一覧には連絡先の名前や一般的な語も入るが、読みと単語が同じものは変換の役に立たないので除く。
/// 読みがひらがな・カタカナでないもの（英字の短縮形など）も、日本語の変換では打てないので除く。
public enum SystemLexicon {
    /// 取り込む上限（大量に登録している場合でも変換を遅くしないため）
    public static let maximumCount = 2000

    public static func userDictionaryEntries(from pairs: [(input: String, text: String)]) -> [UserDictionaryEntry] {
        var result: [UserDictionaryEntry] = []
        var seen = Set<String>()
        for (input, text) in pairs {
            let reading = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reading.isEmpty, reading.count <= 40, !text.isEmpty, text.count <= 500, text != reading,
                  reading.allSatisfy({ $0.isHiraganaForReading || $0.isKatakanaForReading }) else {
                continue
            }
            let hiragana = reading.katakanaToHiragana
            guard text != hiragana, seen.insert(hiragana + "\n" + text).inserted else {
                continue
            }
            result.append(UserDictionaryEntry(word: text, reading: hiragana, category: .phrase))
            if result.count >= maximumCount {
                break
            }
        }
        return result
    }

    /// 英字の短縮形（"omw" → "On my way!"など）。キーは小文字にそろえる。英字で打っているときの候補に使う。
    public static func englishShortcuts(from pairs: [(input: String, text: String)]) -> [String: String] {
        var result: [String: String] = [:]
        for (input, text) in pairs {
            let key = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, key.count <= 40, !text.isEmpty, text.count <= 500, text.lowercased() != key,
                  key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }), result[key] == nil else {
                continue
            }
            result[key] = text
            if result.count >= maximumCount {
                break
            }
        }
        return result
    }
}
