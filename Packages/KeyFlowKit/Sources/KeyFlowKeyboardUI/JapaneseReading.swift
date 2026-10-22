#if os(iOS)
import Foundation
import CoreFoundation

/// 漢字かな交じりの文字列の読みを推定する（選択したテキストの再変換に使う）。
/// iOSの形態素解析（CFStringTokenizer）でローマ字表記を得て、カタカナに直す。
public enum JapaneseReading {
    public static func reading(of text: String) -> String? {
        let input = text as NSString
        guard input.length > 0 else { return nil }
        let locale = Locale(identifier: "ja_JP") as CFLocale
        guard let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            input as CFString,
            CFRangeMake(0, input.length),
            kCFStringTokenizerUnitWordBoundary,
            locale
        ) else {
            return nil
        }
        let output = NSMutableString()
        var tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0)
        while tokenType.rawValue != 0 {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let original = input.substring(with: NSRange(location: range.location, length: range.length))
            if original.unicodeScalars.allSatisfy({ $0.isASCII }) {
                // 英数字はそのまま残す
                output.append(original)
            } else if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                let reading = NSMutableString(string: latin)
                CFStringTransform(reading as CFMutableString, nil, kCFStringTransformLatinKatakana, false)
                output.append(reading as String)
            } else {
                output.append(original)
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        let result = output as String
        return result.isEmpty ? nil : result
    }
}
#endif
