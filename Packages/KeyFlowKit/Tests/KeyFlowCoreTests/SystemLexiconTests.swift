import Foundation
import Testing
@testable import KeyFlowCore

@Suite("iPhoneのユーザ辞書")
struct SystemLexiconTests {
    @Test("読みがかなの登録だけを取り込み、カタカナの読みはひらがなにする")
    func filters() {
        let entries = SystemLexicon.userDictionaryEntries(from: [
            ("よろ", "よろしくお願いします"),
            ("メアド", "taro@example.com"),
            ("omw", "On my way!"),
            ("田中", "田中"),
            ("たなか", "たなか"),
            ("ヤマダ", "やまだ"),
            ("", "空"),
            ("よろ", "よろしくお願いします"),
        ])
        #expect(entries.map(\.reading) == ["よろ", "めあど"])
        #expect(entries.map(\.word) == ["よろしくお願いします", "taro@example.com"])
        #expect(entries.allSatisfy { $0.category == .phrase })
    }

    @Test("取り込む数に上限がある")
    func limit() {
        let pairs = (0..<3000).map { (input: "あ", text: "単語\($0)") }
        #expect(SystemLexicon.userDictionaryEntries(from: pairs).count == SystemLexicon.maximumCount)
    }
}
