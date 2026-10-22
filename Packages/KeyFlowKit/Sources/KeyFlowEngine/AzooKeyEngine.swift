import Foundation
import KeyFlowCore
import KanaKanjiConverterModuleWithDefaultDictionary

/// AzooKeyKanaKanjiConverterを使った変換エンジン。
///
/// スレッドセーフではない。`ConversionQueue`の直列キューからのみ呼び出すこと。
public final class AzooKeyEngine: ConversionEngine {
    /// 辞書の準備に時間がかかるため、最初に使うとき（変換キュー上）に作る。
    /// メモリが足りなくなったときは捨てて、次に使うときに作り直す。
    private var loadedConverter: KanaKanjiConverter?
    private var converter: KanaKanjiConverter {
        if let loadedConverter {
            return loadedConverter
        }
        let c = KanaKanjiConverter.withDefaultDictionary(preloadDictionary: false)
        if !userDictionary.isEmpty {
            c.importDynamicUserDictionary(userDictionary)
        }
        loadedConverter = c
        return c
    }
    private var userDictionary: [DicdataElement] = []
    private let memoryDirectory: URL
    private let sharedDirectory: URL
    private let versionString: String

    /// 直近の変換結果（確定時に学習用の元データを引くため）
    private var lastResult: (requestID: Int, composing: ComposingText, candidates: [Candidate])?
    /// 直近の次の語の予測（確定時に学習用の元データを引くため）
    private var lastNextWord: (requestID: Int, base: Candidate, predictions: [PostCompositionPredictionCandidate])?
    /// 最後に確定した候補（次の語の予測の起点）
    private var lastCommitted: Candidate?
    private let textReplacer = TextReplacer.withDefaultEmojiDictionary()

    /// - Parameters:
    ///   - memoryDirectory: 学習データを書き込むディレクトリ（キーボード拡張自身のコンテナ）
    ///   - sharedDirectory: 読み取り専用で参照する共有ディレクトリ（App Group）。無ければ`memoryDirectory`
    public init(memoryDirectory: URL, sharedDirectory: URL? = nil, versionString: String = "KeyFlow") {
        self.memoryDirectory = memoryDirectory
        self.sharedDirectory = sharedDirectory ?? memoryDirectory
        self.versionString = versionString
        try? FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
    }

    private func requestOptions(_ o: ConversionOptions, prediction: Bool) -> ConvertRequestOptions {
        ConvertRequestOptions(
            N_best: 10,
            requireJapanesePrediction: prediction && o.predictionEnabled ? .manualMix : .disabled,
            requireEnglishPrediction: .disabled,
            keyboardLanguage: .ja_JP,
            englishCandidateInRoman2KanaInput: false,
            fullWidthRomanCandidate: true,
            halfWidthKanaCandidate: false,
            learningType: o.learningEnabled ? .inputAndOutput : .nothing,
            maxMemoryCount: 65536,
            shouldResetMemory: false,
            memoryDirectoryURL: memoryDirectory,
            sharedContainerURL: sharedDirectory,
            textReplacer: textReplacer,
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: .off,
            metadata: .init(versionString: versionString)
        )
    }

    public func candidates(for source: String, requestID: Int, options: ConversionOptions) -> CandidateList {
        guard !source.isEmpty else {
            return CandidateList(requestID: requestID, source: source, candidates: [])
        }
        var composing = ComposingText()
        composing.insertAtCursorPosition(source, inputStyle: .direct)
        let result = converter.requestCandidates(composing, options: requestOptions(options, prediction: true))

        // 並び順: 入力全体の変換の1位 → 予測（最大3件）→ 残りの変換 → 残りの予測
        // 「変換」キーでは予測を飛ばして変換候補だけを巡回する（InputController側）
        let exact = ConversionHeuristics.reorder(
            result.mainResults.filter { $0.inputable && !$0.text.isEmpty },
            text: { $0.text },
            score: { $0.value }
        )
        let predictions = result.predictionResults.filter { $0.inputable && !$0.text.isEmpty }
        var ordered: [(Candidate, Bool)] = []
        ordered += exact.prefix(1).map { ($0, false) }
        ordered += predictions.prefix(3).map { ($0, true) }
        ordered += exact.dropFirst().map { ($0, false) }
        ordered += predictions.dropFirst(3).map { ($0, true) }

        var seen = Set<String>()
        var natives: [Candidate] = []
        var candidates: [ConversionCandidate] = []
        let total = composing.convertTarget.count
        for (c, isPrediction) in ordered {
            if !options.emojiCandidates, c.text.isEmojiOnly { continue }
            guard seen.insert(c.text).inserted else { continue }
            var rest = composing
            rest.prefixComplete(composingCount: c.composingCount)
            let consumed = max(1, total - rest.convertTarget.count)
            candidates.append(ConversionCandidate(text: c.text, consumedCount: consumed, isPrediction: isPrediction, engineIndex: natives.count))
            natives.append(c)
        }
        lastResult = (requestID, composing, natives)
        return CandidateList(requestID: requestID, source: source, candidates: candidates)
    }

    public func commit(_ candidate: ConversionCandidate, of list: CandidateList, remaining: String, options: ConversionOptions) {
        switch candidate.kind {
        case .conversion:
            guard let last = lastResult, last.requestID == list.requestID, last.candidates.indices.contains(candidate.engineIndex) else {
                converter.stopComposition()
                return
            }
            let native = last.candidates[candidate.engineIndex]
            if options.learningEnabled {
                converter.updateLearningData(native)
            }
            if remaining.isEmpty {
                converter.stopComposition()
                lastCommitted = native
            } else {
                // 残りの入力を変換するときに、確定した文節を左文脈として使う
                converter.setCompletedData(native)
                lastCommitted = nil
            }
        case .nextWord:
            guard let next = lastNextWord, next.requestID == list.requestID, next.predictions.indices.contains(candidate.engineIndex) else {
                return
            }
            let prediction = next.predictions[candidate.engineIndex]
            if options.learningEnabled {
                converter.updateLearningData(next.base, with: prediction)
            }
            lastCommitted = prediction.isTerminal ? nil : prediction.join(to: next.base)
        }
    }

    public func nextWordCandidates(after committed: ConversionCandidate, requestID: Int, options: ConversionOptions) -> CandidateList {
        guard let base = lastCommitted else {
            return CandidateList(requestID: requestID, source: "", candidates: [])
        }
        let predictions = converter.requestPostCompositionPredictionCandidates(leftSideCandidate: base, options: requestOptions(options, prediction: false))
        // 直前の確定を置き換える種類の予測は、入力欄の書き換えが必要になるため使わない
        var usable: [PostCompositionPredictionCandidate] = []
        var seen = Set<String>()
        for p in predictions {
            guard case .additional = p.type, !p.text.isEmpty else { continue }
            if !options.emojiCandidates, p.text.isEmojiOnly { continue }
            guard seen.insert(p.text).inserted else { continue }
            usable.append(p)
            if usable.count >= 12 { break }
        }
        lastNextWord = (requestID, base, usable)
        let candidates = usable.enumerated().map { index, p in
            ConversionCandidate(text: p.text, consumedCount: 0, kind: .nextWord, engineIndex: index)
        }
        return CandidateList(requestID: requestID, source: "", candidates: candidates)
    }

    public func resetComposition() {
        converter.stopComposition()
    }

    /// 変換器と辞書の一部を先に読み込んでおく（キーボード表示直後の最初の変換を速くする）
    public func warmUp() {
        var composing = ComposingText()
        composing.insertAtCursorPosition("あ", inputStyle: .direct)
        _ = converter.requestCandidates(composing, options: requestOptions(ConversionOptions(), prediction: false))
        converter.stopComposition()
    }

    public func flushLearning() {
        converter.commitUpdateLearningData()
    }

    public func resetLearning() {
        converter.resetMemory()
        lastCommitted = nil
    }

    public func updateUserDictionary(_ entries: [UserDictionaryEntry]) {
        let elements: [DicdataElement] = entries.compactMap { entry in
            let ruby = entry.reading.toKatakanaForDictionary()
            guard !ruby.isEmpty, !entry.word.isEmpty else { return nil }
            let (cid, mid): (Int, Int) = switch entry.category {
            case .noun: (CIDData.一般名詞.cid, MIDData.一般.mid)
            case .personName: (CIDData.人名一般.cid, MIDData.一般.mid)
            case .placeName: (CIDData.地名一般.cid, MIDData.一般.mid)
            case .organization: (CIDData.固有名詞組織.cid, MIDData.組織.mid)
            case .phrase: (CIDData.固有名詞.cid, MIDData.一般.mid)
            }
            return DicdataElement(word: entry.word, ruby: ruby, cid: cid, mid: mid, value: -5)
        }
        userDictionary = elements
        converter.importDynamicUserDictionary(elements)
    }

    /// 読み込んだ辞書を手放してメモリを空ける（学習データは保存してから）
    public func purgeMemory() {
        guard let loadedConverter else { return }
        loadedConverter.commitUpdateLearningData()
        self.loadedConverter = nil
        lastResult = nil
        lastNextWord = nil
        lastCommitted = nil
    }
}

extension String {
    /// 絵文字だけでできている
    var isEmojiOnly: Bool {
        !isEmpty && allSatisfy { c in
            c.unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }
        }
    }

    /// 辞書の読み（カタカナ）に変換する
    func toKatakanaForDictionary() -> String {
        String(String.UnicodeScalarView(self.unicodeScalars.map { scalar in
            // ひらがな（ぁ〜ゖ）をカタカナへ
            if (0x3041...0x3096).contains(scalar.value), let k = Unicode.Scalar(scalar.value + 0x60) {
                return k
            }
            return scalar
        }))
    }
}
