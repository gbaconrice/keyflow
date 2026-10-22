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
}
