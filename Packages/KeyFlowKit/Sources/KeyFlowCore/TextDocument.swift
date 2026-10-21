import Foundation

/// `UITextDocumentProxy`のうち、入力処理で使う部分だけを抜き出したもの。
///
/// 入力状態管理をUIKitから切り離してテストできるようにするための抽象。
/// 拡張機能では`UITextDocumentProxy`をラップした実装を使い、テストでは`SimulatedTextField`を使う。
public protocol TextDocument: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var selectedText: String? { get }
    var hasText: Bool { get }
    func insertText(_ text: String)
    func deleteBackward()
    /// UTF-16単位のオフセットでカーソルを動かす（UIKitの仕様に合わせる）
    func adjustTextPosition(byCharacterOffset offset: Int)
    /// 入力中の文字列を下線付きで表示する。`selectedRange`はUTF-16単位。
    func setMarkedText(_ text: String, selectedRange: NSRange)
    func unmarkText()
}

/// ホストアプリのテキストフィールドを模したもの。テストとアプリ内プレビューで使う。
///
/// marked textの扱いはUIKitの`UITextInput`の挙動に合わせている。
/// - `insertText`はmarked textがあればそれを置き換える
/// - `deleteBackward`はmarked textがあればその末尾を1文字消す
/// - `documentContextBeforeInput`はカーソルより前の文字列（marked textを含む）
public final class SimulatedTextField: TextDocument {
    /// 確定済み部分も含めた全文
    public private(set) var text: String = ""
    /// カーソル位置（Character単位）
    public private(set) var cursor: Int = 0
    /// marked textの範囲（Character単位）
    public private(set) var markedRange: Range<Int>?
    /// 呼び出し履歴（テストで操作回数を確認するため）
    public private(set) var operationLog: [String] = []

    public init(text: String = "", cursor: Int? = nil) {
        self.text = text
        self.cursor = cursor ?? text.count
    }

    private var chars: [Character] { Array(text) }

    public var markedText: String? {
        guard let r = markedRange else { return nil }
        return String(chars[r])
    }

    public var documentContextBeforeInput: String? {
        String(chars[0..<cursor])
    }

    public var documentContextAfterInput: String? {
        String(chars[cursor...])
    }

    public var selectedText: String? { nil }

    public var hasText: Bool { !text.isEmpty }

    public func insertText(_ insert: String) {
        operationLog.append("insert(\(insert))")
        var c = chars
        if let r = markedRange {
            c.replaceSubrange(r, with: Array(insert))
            cursor = r.lowerBound + insert.count
            markedRange = nil
        } else {
            c.insert(contentsOf: Array(insert), at: cursor)
            cursor += insert.count
        }
        text = String(c)
    }

    public func deleteBackward() {
        operationLog.append("delete")
        var c = chars
        if let r = markedRange {
            // UIKitではmarked textのカーソル直前を1文字消す
            guard cursor > r.lowerBound else { return }
            c.remove(at: cursor - 1)
            cursor -= 1
            let newUpper = r.upperBound - 1
            markedRange = newUpper > r.lowerBound ? r.lowerBound..<newUpper : nil
        } else {
            guard cursor > 0 else { return }
            c.remove(at: cursor - 1)
            cursor -= 1
        }
        text = String(c)
    }

    public func adjustTextPosition(byCharacterOffset offset: Int) {
        operationLog.append("move(\(offset))")
        // UTF-16オフセットをCharacter単位に変換する
        let c = chars
        var remaining = offset
        var position = cursor
        if remaining > 0 {
            while remaining > 0, position < c.count {
                remaining -= String(c[position]).utf16.count
                position += 1
            }
        } else {
            while remaining < 0, position > 0 {
                remaining += String(c[position - 1]).utf16.count
                position -= 1
            }
        }
        if markedRange != nil {
            // カーソル移動でmarked textは確定される（UIKitの挙動）
            markedRange = nil
        }
        cursor = position
    }

    public func setMarkedText(_ marked: String, selectedRange: NSRange) {
        operationLog.append("mark(\(marked))")
        var c = chars
        let start: Int
        if let r = markedRange {
            c.replaceSubrange(r, with: Array(marked))
            start = r.lowerBound
        } else {
            c.insert(contentsOf: Array(marked), at: cursor)
            start = cursor
        }
        text = String(c)
        if marked.isEmpty {
            markedRange = nil
            cursor = start
        } else {
            markedRange = start..<(start + marked.count)
            // selectedRangeはUTF-16単位なのでCharacter単位に直す
            let prefix = String(marked.utf16.prefix(selectedRange.location)) ?? marked
            cursor = start + prefix.count
        }
    }

    public func unmarkText() {
        operationLog.append("unmark")
        if let r = markedRange {
            cursor = r.upperBound
        }
        markedRange = nil
    }

    /// ユーザーが別の場所をタップしたときなど、ホスト側でカーソルが動いた状況を再現する
    public func simulateUserTap(at position: Int) {
        markedRange = nil
        cursor = max(0, min(position, text.count))
    }

    public func clearLog() {
        operationLog.removeAll()
    }
}
