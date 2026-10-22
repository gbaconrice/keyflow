import Foundation

/// ローマ字をひらがなに変える。
///
/// 変換表は、変換エンジンと同じAzooKeyKanaKanjiConverter（MIT License）の
/// `defaultRoman2Kana`をもとにしている。規則も同じにしている。
/// - 表にある綴りはかなにする（"kya"→「きゃ」）
/// - 同じ子音が続くと「っ」（"kk"→「っk」）
/// - "n"の後に母音・"y"・"n"以外が来ると「ん」（"nk"→「んk」）。"nn"も「ん」
/// - 表の綴りの途中（"k"、"ky"など）は英字のまま残し、続きの入力を待つ
public enum RomajiConverter {
    /// ローマ字として読む文字（小文字の英字）
    public static func isRomajiLetter(_ c: Character) -> Bool {
        c.isASCII && c.isLowercase && c.isLetter
    }

    /// 英字の並びをかなに変える。綴りの途中の英字は末尾に残る。
    public static func convert(_ input: String) -> String {
        var result = ""
        var buffer = ""
        for c in input {
            buffer.append(c)
            resolve(&buffer, into: &result, final: false)
        }
        return result + buffer
    }

    /// 入力の区切り（変換・確定・記号の入力）で、残っている英字を確定する。末尾の"n"は「ん」にする。
    public static func flush(_ input: String) -> String {
        var result = ""
        var buffer = ""
        for c in input {
            buffer.append(c)
            resolve(&buffer, into: &result, final: false)
        }
        resolve(&buffer, into: &result, final: true)
        return result + buffer
    }

    private static func resolve(_ buffer: inout String, into result: inout String, final: Bool) {
        while !buffer.isEmpty {
            if !final, prefixes.contains(buffer) {
                return
            }
            if let out = table[buffer] {
                // 「っk」のように英字が残る出力は、残りを次の入力と合わせて読む
                let kana = String(out.prefix { !$0.isASCII })
                result += kana
                buffer = String(out.dropFirst(kana.count))
                continue
            }
            if buffer.first == "n", buffer.count >= 2 || final {
                result += "ん"
                buffer.removeFirst()
                continue
            }
            // 表にない綴りは、先頭の1文字を英字のまま確定して残りを読み直す
            result.append(buffer.removeFirst())
        }
    }

    /// 表の綴りの途中になりうる文字列（"k"、"ky"、"lts"など）
    private static let prefixes: Set<String> = {
        var set = Set<String>()
        for key in table.keys {
            var p = ""
            for c in key.dropLast() {
                p.append(c)
                set.insert(p)
            }
        }
        return set
    }()

    static let table: [String: String] = [
        "a": "あ", "xa": "ぁ", "la": "ぁ", "i": "い", "xi": "ぃ", "li": "ぃ",
        "u": "う", "wu": "う", "vu": "ゔ", "xu": "ぅ", "lu": "ぅ", "e": "え",
        "xe": "ぇ", "le": "ぇ", "o": "お", "xo": "ぉ", "lo": "ぉ", "ka": "か",
        "ca": "か", "ga": "が", "xka": "ゕ", "lka": "ゕ", "ki": "き", "gi": "ぎ",
        "ku": "く", "cu": "く", "gu": "ぐ", "ke": "け", "ge": "げ", "xke": "ゖ",
        "lke": "ゖ", "ko": "こ", "co": "こ", "go": "ご", "sa": "さ", "za": "ざ",
        "si": "し", "ci": "し", "shi": "し", "zi": "じ", "ji": "じ", "su": "す",
        "zu": "ず", "se": "せ", "ce": "せ", "ze": "ぜ", "so": "そ", "zo": "ぞ",
        "ta": "た", "da": "だ", "ti": "ち", "chi": "ち", "di": "ぢ", "tu": "つ",
        "tsu": "つ", "xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ", "du": "づ",
        "te": "て", "de": "で", "to": "と", "do": "ど", "na": "な", "ni": "に",
        "nu": "ぬ", "ne": "ね", "no": "の", "ha": "は", "ba": "ば", "pa": "ぱ",
        "hi": "ひ", "bi": "び", "pi": "ぴ", "hu": "ふ", "fu": "ふ", "bu": "ぶ",
        "pu": "ぷ", "he": "へ", "be": "べ", "pe": "ぺ", "ho": "ほ", "bo": "ぼ",
        "po": "ぽ", "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "ya": "や", "xya": "ゃ", "lya": "ゃ", "yu": "ゆ", "xyu": "ゅ", "lyu": "ゅ",
        "yo": "よ", "xyo": "ょ", "lyo": "ょ", "ra": "ら", "ri": "り", "ru": "る",
        "re": "れ", "ro": "ろ", "wa": "わ", "xwa": "ゎ", "lwa": "ゎ", "wyi": "ゐ",
        "wye": "ゑ", "wo": "を", "nn": "ん", "ye": "いぇ", "va": "ゔぁ", "vi": "ゔぃ",
        "ve": "ゔぇ", "vo": "ゔぉ", "kya": "きゃ", "kyu": "きゅ", "kye": "きぇ", "kyo": "きょ",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gye": "ぎぇ", "gyo": "ぎょ", "qa": "くぁ", "kwa": "くぁ",
        "qwa": "くぁ", "qi": "くぃ", "kwi": "くぃ", "qwi": "くぃ", "qu": "くぅ", "kwu": "くぅ",
        "qwu": "くぅ", "qe": "くぇ", "kwe": "くぇ", "qwe": "くぇ", "qo": "くぉ", "kwo": "くぉ",
        "qwo": "くぉ", "gwa": "ぐぁ", "gwi": "ぐぃ", "gwu": "ぐぅ", "gwe": "ぐぇ", "gwo": "ぐぉ",
        "sha": "しゃ", "sya": "しゃ", "shu": "しゅ", "syu": "しゅ", "she": "しぇ", "sye": "しぇ",
        "sho": "しょ", "syo": "しょ", "ja": "じゃ", "zya": "じゃ", "jya": "じゃ", "jyi": "じぃ",
        "ju": "じゅ", "zyu": "じゅ", "jyu": "じゅ", "je": "じぇ", "zye": "じぇ", "jye": "じぇ",
        "jo": "じょ", "zyo": "じょ", "jyo": "じょ", "swa": "すぁ", "swi": "すぃ", "swu": "すぅ",
        "swe": "すぇ", "swo": "すぉ", "cha": "ちゃ", "cya": "ちゃ", "tya": "ちゃ", "tyi": "ちぃ",
        "cyi": "ちぃ", "chu": "ちゅ", "cyu": "ちゅ", "tyu": "ちゅ", "che": "ちぇ", "cye": "ちぇ",
        "tye": "ちぇ", "cho": "ちょ", "cyo": "ちょ", "tyo": "ちょ", "tsa": "つぁ", "tsi": "つぃ",
        "tse": "つぇ", "tso": "つぉ", "tha": "てゃ", "thi": "てぃ", "thu": "てゅ", "the": "てぇ",
        "tho": "てょ", "twa": "とぁ", "twi": "とぃ", "twu": "とぅ", "twe": "とぇ", "two": "とぉ",
        "dya": "ぢゃ", "dyi": "ぢぃ", "dyu": "ぢゅ", "dye": "ぢぇ", "dyo": "ぢょ", "dha": "でゃ",
        "dhi": "でぃ", "dhu": "でゅ", "dhe": "でぇ", "dho": "でょ", "dwa": "どぁ", "dwi": "どぃ",
        "dwu": "どぅ", "dwe": "どぇ", "dwo": "どぉ", "nya": "にゃ", "nyi": "にぃ", "nyu": "にゅ",
        "nye": "にぇ", "nyo": "にょ", "hya": "ひゃ", "hyi": "ひぃ", "hyu": "ひゅ", "hye": "ひぇ",
        "hyo": "ひょ", "bya": "びゃ", "byi": "びぃ", "byu": "びゅ", "bye": "びぇ", "byo": "びょ",
        "pya": "ぴゃ", "pyi": "ぴぃ", "pyu": "ぴゅ", "pye": "ぴぇ", "pyo": "ぴょ", "fa": "ふぁ",
        "hwa": "ふぁ", "fwa": "ふぁ", "fi": "ふぃ", "hwi": "ふぃ", "fwi": "ふぃ", "fwu": "ふぅ",
        "fe": "ふぇ", "hwe": "ふぇ", "fwe": "ふぇ", "fo": "ふぉ", "hwo": "ふぉ", "fwo": "ふぉ",
        "fya": "ふゃ", "fyu": "ふゅ", "fyo": "ふょ", "mya": "みゃ", "myi": "みぃ", "myu": "みゅ",
        "mye": "みぇ", "myo": "みょ", "rya": "りゃ", "ryi": "りぃ", "ryu": "りゅ", "rye": "りぇ",
        "ryo": "りょ", "wi": "うぃ", "we": "うぇ", "wha": "うぁ", "whi": "うぃ", "whu": "う",
        "whe": "うぇ", "who": "うぉ", "bb": "っb", "cc": "っc", "dd": "っd", "ff": "っf",
        "gg": "っg", "hh": "っh", "jj": "っj", "kk": "っk", "ll": "っl", "mm": "っm",
        "pp": "っp", "qq": "っq", "rr": "っr", "ss": "っs", "tt": "っt", "vv": "っv",
        "ww": "っw", "xx": "っx", "yy": "っy", "zz": "っz", "xn": "ん", "zh": "←",
        "zj": "↓", "zk": "↑", "zl": "→",
    ]
}
