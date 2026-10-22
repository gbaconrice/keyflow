import Foundation

/// 入力中（未確定）のかな文字列とその中のカーソル位置
public struct Composition: Sendable, Equatable {
    public private(set) var characters: [Character]
    /// カーソル位置（Character単位, 0...count）
    public private(set) var cursor: Int

    public init(_ text: String = "", cursor: Int? = nil) {
        self.characters = Array(text)
        self.cursor = cursor ?? characters.count
    }

    public var text: String { String(characters) }
    public var isEmpty: Bool { characters.isEmpty }
    public var count: Int { characters.count }
    public var textBeforeCursor: String { String(characters[0..<cursor]) }
    public var isCursorAtEnd: Bool { cursor == characters.count }

    public mutating func insert(_ s: String) {
        let new = Array(s)
        characters.insert(contentsOf: new, at: cursor)
        cursor += new.count
    }

    /// カーソル直前の1文字を消す。消せなければfalse。
    @discardableResult
    public mutating func deleteBackward() -> Bool {
        guard cursor > 0 else { return false }
        characters.remove(at: cursor - 1)
        cursor -= 1
        return true
    }

    /// カーソル直前の1文字を置き換える
    public mutating func replaceCharacterBeforeCursor(with c: Character) {
        guard cursor > 0 else { return }
        characters[cursor - 1] = c
    }

    public var characterBeforeCursor: Character? {
        cursor > 0 ? characters[cursor - 1] : nil
    }

    /// カーソルを動かす。実際に動いた量を返す。
    @discardableResult
    public mutating func moveCursor(by offset: Int) -> Int {
        let target = max(0, min(characters.count, cursor + offset))
        let moved = target - cursor
        cursor = target
        return moved
    }

    /// 先頭から`count`文字を取り除く（候補を確定したとき）
    public mutating func removePrefix(_ count: Int) {
        let n = max(0, min(count, characters.count))
        characters.removeFirst(n)
        cursor = max(0, cursor - n)
    }
}

/// 変換候補
public struct ConversionCandidate: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// 通常の変換結果
        case conversion
        /// 確定後の次の語の予測
        case nextWord
    }

    public var text: String
    /// 入力中の文字列のうち、この候補が先頭から何文字分を置き換えるか
    public var consumedCount: Int
    public var kind: Kind
    /// 入力の続きを予測した候補（「変換」キーの巡回では飛ばす）
    public var isPrediction: Bool
    /// エンジン側で学習に使う元データを引くための番号
    public var engineIndex: Int

    public init(text: String, consumedCount: Int, kind: Kind = .conversion, isPrediction: Bool = false, engineIndex: Int) {
        self.text = text
        self.consumedCount = consumedCount
        self.kind = kind
        self.isPrediction = isPrediction
        self.engineIndex = engineIndex
    }
}

/// 1回の変換要求の結果
public struct CandidateList: Sendable, Equatable {
    /// どの変換要求に対する結果か（古い結果を捨てるために使う）
    public var requestID: Int
    /// 変換対象（入力中の文字列のうちカーソルより前）
    public var source: String
    public var candidates: [ConversionCandidate]

    public init(requestID: Int, source: String, candidates: [ConversionCandidate]) {
        self.requestID = requestID
        self.source = source
        self.candidates = candidates
    }

    public static let empty = CandidateList(requestID: -1, source: "", candidates: [])
}

/// 変換の設定（`KeyboardSettings`から必要な部分だけを渡す）
public struct ConversionOptions: Sendable, Equatable {
    public var learningEnabled: Bool
    public var predictionEnabled: Bool
    public var emojiCandidates: Bool
    /// 直前の文脈（カーソルより左の確定済み文字列の末尾）
    public var leftContext: String

    public init(learningEnabled: Bool = true, predictionEnabled: Bool = true, emojiCandidates: Bool = true, leftContext: String = "") {
        self.learningEnabled = learningEnabled
        self.predictionEnabled = predictionEnabled
        self.emojiCandidates = emojiCandidates
        self.leftContext = leftContext
    }
}

/// かな漢字変換エンジンの抽象。
///
/// 実装はスレッドセーフでなくてよい。`ConversionQueue`が常に同じ直列キューから呼び出す。
public protocol ConversionEngine: AnyObject {
    /// `source`（ひらがな等）を変換して候補を返す
    func candidates(for source: String, requestID: Int, options: ConversionOptions) -> CandidateList
    /// 候補を確定したことを伝える（学習・文脈の更新）
    /// - Parameter remaining: 確定後に残る入力中の文字列（空なら入力終了）
    func commit(_ candidate: ConversionCandidate, of list: CandidateList, remaining: String, options: ConversionOptions)
    /// 確定後に続く語の候補
    func nextWordCandidates(after committed: ConversionCandidate, requestID: Int, options: ConversionOptions) -> CandidateList
    /// 入力を中断・終了した（変換キャッシュの破棄）
    func resetComposition()
    /// 学習データをディスクへ保存する
    func flushLearning()
    /// 学習データを消去する
    func resetLearning()
    /// ユーザー辞書を差し替える
    func updateUserDictionary(_ entries: [UserDictionaryEntry])
    /// メモリが足りないときに、作り直せるキャッシュを捨てる
    func purgeMemory()
    /// 候補の学習を取り消す
    func forget(_ candidate: ConversionCandidate, of list: CandidateList)
}

extension ConversionEngine {
    public func purgeMemory() {}
    public func forget(_ candidate: ConversionCandidate, of list: CandidateList) {}
}

/// ユーザー辞書の1語
public struct UserDictionaryEntry: Codable, Sendable, Equatable, Identifiable, Hashable {
    public enum Category: String, Codable, Sendable, CaseIterable {
        case noun
        case personName
        case placeName
        case organization
        case phrase
    }

    public var id: UUID
    /// 単語（変換後の表記）
    public var word: String
    /// 読み（ひらがな）
    public var reading: String
    public var category: Category

    public init(id: UUID = UUID(), word: String, reading: String, category: Category = .noun) {
        self.id = id
        self.word = word
        self.reading = reading
        self.category = category
    }
}
