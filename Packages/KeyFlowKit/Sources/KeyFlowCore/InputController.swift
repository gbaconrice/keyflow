import Foundation

/// 改行キーの種類（`UIReturnKeyType`に対応）
public enum ReturnKeyKind: Sendable, Equatable {
    case `default`, go, search, send, done, next, join, route, `continue`, emergencyCall

    var label: String {
        switch self {
        case .default: "改行"
        case .go: "開く"
        case .search: "検索"
        case .send: "送信"
        case .done: "完了"
        case .next: "次へ"
        case .join: "接続"
        case .route: "経路"
        case .continue: "続ける"
        case .emergencyCall: "緊急"
        }
    }

    var englishLabel: String {
        switch self {
        case .default: "return"
        case .go: "go"
        case .search: "search"
        case .send: "send"
        case .done: "done"
        case .next: "next"
        case .join: "join"
        case .route: "route"
        case .continue: "continue"
        case .emergencyCall: "call"
        }
    }
}

public enum ShiftState: Sendable, Equatable {
    case off
    case once
    case locked
}

/// 入力欄の種類に応じた初期モードの決定に使う
public enum InputFieldKind: Sendable, Equatable {
    case normal
    case url
    case email
    case ascii
    case number
}

/// UIに表示するための状態
public struct InputViewState: Sendable, Equatable {
    public var mode: KeyboardMode = .kana
    public var isComposing = false
    public var candidates: [ConversionCandidate] = []
    /// 候補の要求ID（候補をタップしたときに、表示中の一覧と一致するか確かめる）
    public var candidateRequestID = -1
    public var selectedCandidateIndex: Int?
    /// 直前の確定を取り消して読みに戻せる
    public var canUndoCommit = false
    public var spaceKeyLabel = "空白"
    public var enterKeyLabel = "改行"
    /// 改行キーを強調表示する（確定・検索・送信など）
    public var enterKeyEmphasized = false
    /// 入力欄が空で改行キーを押せない（`enablesReturnKeyAutomatically`）
    public var enterKeyDisabled = false
    public var shift: ShiftState = .off
    public var isToggleActive = false
    /// 選択中のテキストの変換候補を表示している
    public var isReconverting = false

    public init() {}
}

/// キー入力を受け取り、入力中の文字列・変換候補・ホストの入力欄を更新する。
///
/// メインスレッドからのみ呼び出す。変換は`ConversionQueue`で非同期に行い、
/// 入力欄への反映（marked textの更新）は常に即座に行うので、変換が遅れても文字は欠落しない。
public final class InputController {
    public private(set) var state = InputViewState()
    public var settings: KeyboardSettings

    /// 状態が変わったときに呼ばれる
    public var onStateChange: ((InputViewState) -> Void)?

    public var document: (any TextDocument)?
    private let conversion: ConversionQueue
    private let now: () -> Date

    private var mode: KeyboardMode = .kana
    private var composition = Composition()
    private var candidateList = CandidateList.empty
    private var selectedIndex: Int?
    private var toggle: ToggleState?
    private var lastCommit: (text: String, reading: String)?
    private var shift: ShiftState = .off
    private var lastShiftTap: Date?
    private var returnKey: ReturnKeyKind = .default
    private var enablesReturnKeyAutomatically = false
    /// marked textを使わない場合に、入力中の文字列として入力欄に挿入済みの文字列
    private var displayedPlainText = ""
    /// 自分で入力欄を操作した直後の状態（外部からの変更を見分けるため）
    private var expectedContext: (before: String?, after: String?, time: Date)?
    /// 選択中のテキストを変換し直している（選択文字列とその読み）
    private var reconversion: (selected: String, reading: String)?

    /// 漢字を含む文字列の読み（ひらがな）を推定する。iOSではシステムの形態素解析を使う。
    public var readingProvider: ((String) -> String?)?

    private struct ToggleState {
        var keyID: String
        var cycle: [String]
        var index: Int
        var time: Date
        var current: String { cycle[index] }
    }

    public init(settings: KeyboardSettings, conversion: ConversionQueue, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.conversion = conversion
        self.now = now
        conversion.onCandidates = { [weak self] list in
            self?.receive(list)
        }
        rebuildState()
    }

    // MARK: - 入力欄の情報

    /// 入力欄が切り替わったとき（テキストフィールドの切替、キーボードの再表示）
    public func configure(returnKey: ReturnKeyKind, enablesReturnKeyAutomatically: Bool, fieldKind: InputFieldKind) {
        self.returnKey = returnKey
        self.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
        switch fieldKind {
        case .url, .email, .ascii:
            setMode(.english, commitComposition: true)
        case .number:
            setMode(.number, commitComposition: true)
        case .normal:
            break
        }
        rebuildState()
    }

    // MARK: - キー操作

    /// フリックキー（かな・数字・記号）
    public func flick(keyID: String, spec: FlickKeySpec, direction: FlickDirection) {
        beginKeyAction()
        guard let output = spec.output(for: direction) else {
            return
        }
        let t = now()
        if mode == .english {
            flickDirect(keyID: keyID, spec: spec, direction: direction, output: output, time: t)
            return
        }
        flushRomaji()
        // トグル入力: 同じキーの連打で直前の文字を巡回させる
        if direction == .center, settings.toggleInputEnabled, spec.toggleCycle.count > 1,
           var current = toggle, current.keyID == keyID, selectedIndex == nil,
           settings.toggleTimeout <= 0 || t.timeIntervalSince(current.time) <= settings.toggleTimeout,
           composition.textBeforeCursor.hasSuffix(current.current) {
            let previous = current.current
            current.index = (current.index + 1) % current.cycle.count
            current.time = t
            toggle = current
            for _ in 0..<previous.count {
                composition.deleteBackward()
            }
            composition.insert(current.current)
            compositionChanged()
            return
        }
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: true)
        }
        lastCommit = nil
        composition.insert(output)
        if direction == .center, settings.toggleInputEnabled, spec.toggleCycle.count > 1 {
            toggle = ToggleState(keyID: keyID, cycle: spec.toggleCycle, index: spec.toggleCycle.firstIndex(of: output) ?? 0, time: t)
        } else {
            toggle = nil
        }
        compositionChanged()
    }

    /// 英字12キー: 入力中の文字列を使わず、入力欄に直接入れる。トグルは入力欄の直前の文字を置き換える。
    private func flickDirect(keyID: String, spec: FlickKeySpec, direction: FlickDirection, output: String, time t: Date) {
        if direction == .center, settings.toggleInputEnabled, spec.toggleCycle.count > 1,
           var current = toggle, current.keyID == keyID,
           settings.toggleTimeout <= 0 || t.timeIntervalSince(current.time) <= settings.toggleTimeout,
           let document, let before = document.documentContextBeforeInput,
           let last = before.last, String(last).lowercased() == current.current.lowercased() {
            let wasUpper = String(last) != String(last).lowercased()
            current.index = (current.index + 1) % current.cycle.count
            current.time = t
            toggle = current
            document.deleteBackward()
            document.insertText(wasUpper ? current.current.uppercased() : current.current)
            recordExpectedContext()
            rebuildState()
            return
        }
        var text = output
        if shift != .off {
            text = text.uppercased()
            if shift == .once {
                shift = .off
            }
        }
        insertDirect(text)
        if direction == .center, settings.toggleInputEnabled, spec.toggleCycle.count > 1 {
            toggle = ToggleState(keyID: keyID, cycle: spec.toggleCycle, index: spec.toggleCycle.firstIndex(of: output) ?? 0, time: t)
        }
        updateAutoShift()
        rebuildState()
    }

    /// 英字12キーの「a/A」: 直前の英字の大文字・小文字を切り替える
    public func toggleCase() {
        beginKeyAction()
        toggle = nil
        guard composition.isEmpty, let document, let last = document.documentContextBeforeInput?.last, last.isLetter, last.isASCII else {
            return
        }
        let s = String(last)
        let toggled = s == s.lowercased() ? s.uppercased() : s.lowercased()
        document.deleteBackward()
        document.insertText(toggled)
        recordExpectedContext()
        rebuildState()
    }

    /// 記号・顔文字の一覧から選んだ文字列を入れる
    public func insertSymbol(_ text: String) {
        beginKeyAction()
        insertDirect(text)
    }

    /// 文字キー（英字QWERTY・ローマ字入力）
    public func character(_ text: String) {
        beginKeyAction()
        if mode == .kana {
            romajiCharacter(text)
            return
        }
        if mode == .number {
            composeCharacter(text)
            return
        }
        var output = text
        if mode == .english, shift != .off {
            output = text.uppercased()
            if shift == .once {
                shift = .off
            }
        }
        insertDirect(output)
        updateAutoShift()
    }

    /// ローマ字入力の文字キー。小文字の英字はローマ字として読み、それ以外（シフト中の大文字・「ー」）はそのまま入れる。
    private func romajiCharacter(_ text: String) {
        toggle = nil
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: true)
        }
        lastCommit = nil
        var output = text
        if shift != .off {
            output = text.uppercased()
            if shift == .once {
                shift = .off
            }
        }
        if output.count == 1, let c = output.first, RomajiConverter.isRomajiLetter(c) {
            let run = pendingRomaji()
            for _ in 0..<run.count {
                composition.deleteBackward()
            }
            composition.insert(RomajiConverter.convert(run + output))
        } else {
            flushRomaji()
            composition.insert(output)
        }
        compositionChanged()
    }

    /// 数字・記号の文字キー。12キーの数字配列と同じく入力中の文字列に入れる（「3じ」→「3時」のように変換できるように）。
    private func composeCharacter(_ text: String) {
        toggle = nil
        flushRomaji()
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: true)
        }
        lastCommit = nil
        composition.insert(text)
        compositionChanged()
    }

    /// カーソル直前にある、まだかなにしていない英字（ローマ字の綴りの途中）
    private func pendingRomaji() -> String {
        guard settings.kanaLayout == .romaji else { return "" }
        return String(composition.textBeforeCursor.reversed().prefix { RomajiConverter.isRomajiLetter($0) }.reversed())
    }

    /// 綴りの途中の英字を確定する（末尾の"n"を「ん」にする）。入力中の文字列が変わればtrue。
    @discardableResult
    private func flushRomaji() -> Bool {
        let run = pendingRomaji()
        guard !run.isEmpty else { return false }
        let flushed = RomajiConverter.flush(run)
        guard flushed != run else { return false }
        for _ in 0..<run.count {
            composition.deleteBackward()
        }
        composition.insert(flushed)
        return true
    }

    /// 変換に使う読み。ローマ字の綴りの途中の英字は除き、"n"は「ん」として読む。
    private var conversionSource: String {
        let before = composition.textBeforeCursor
        let run = pendingRomaji()
        guard !run.isEmpty else { return before }
        let kana = RomajiConverter.flush(run).prefix { !RomajiConverter.isRomajiLetter($0) }
        return String(before.dropLast(run.count)) + kana
    }

    /// 「小゛゜」キー。centerは巡回、左は濁点、上は小文字、右は半濁点。
    public func modifier(direction: FlickDirection) {
        beginKeyAction()
        toggle = nil
        if selectedIndex != nil {
            selectedIndex = nil
        }
        func modified(_ c: Character) -> Character? {
            switch direction {
            case .center: return KanaModifier.cycle(c)
            case .left: return KanaModifier.toggle(.dakuten, on: c)
            case .up: return KanaModifier.toggle(.small, on: c)
            case .right: return KanaModifier.toggle(.handakuten, on: c)
            case .down: return nil
            }
        }
        if let c = composition.characterBeforeCursor {
            guard let new = modified(c) else {
                rebuildState()
                return
            }
            composition.replaceCharacterBeforeCursor(with: new)
            compositionChanged()
            return
        }
        // 入力中でなければ、確定済みの直前の1文字に適用する
        guard composition.isEmpty, let document, let last = document.documentContextBeforeInput?.last,
              let new = modified(last) else {
            return
        }
        document.deleteBackward()
        document.insertText(String(new))
        lastCommit = nil
        recordExpectedContext()
        rebuildState()
    }

    public func delete() {
        beginKeyAction()
        toggle = nil
        if selectedIndex != nil {
            // 候補選択中は読みに戻す
            selectedIndex = nil
            compositionChanged(requestConversion: false)
            return
        }
        if !composition.isEmpty {
            guard composition.cursor > 0 else {
                return
            }
            composition.deleteBackward()
            compositionChanged()
            return
        }
        lastCommit = nil
        clearIdleCandidates()
        document?.deleteBackward()
        recordExpectedContext()
        updateAutoShift()
        rebuildState()
    }

    public func space() {
        beginKeyAction()
        toggle = nil
        if mode == .english || composition.isEmpty {
            let s = (mode == .english || settings.spaceWidth == .half) ? " " : "　"
            insertDirect(s)
            updateAutoShift()
            return
        }
        if flushRomaji() {
            render()
        }
        refreshCandidatesIfNeeded()
        // 予測候補は飛ばし、入力を変換した候補だけを順に選ぶ
        let cycle = candidateList.candidates.indices.filter { !candidateList.candidates[$0].isPrediction }
        guard !cycle.isEmpty else {
            return
        }
        if let i = selectedIndex, let position = cycle.firstIndex(of: i) {
            selectedIndex = cycle[(position + 1) % cycle.count]
        } else {
            selectedIndex = cycle[0]
        }
        compositionChanged(requestConversion: false)
    }

    public func enter() {
        beginKeyAction()
        toggle = nil
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: false)
            return
        }
        if !composition.isEmpty {
            if flushRomaji() {
                render()
            }
            commitComposition()
            rebuildState()
            return
        }
        clearIdleCandidates()
        lastCommit = nil
        document?.insertText("\n")
        recordExpectedContext()
        updateAutoShift()
        rebuildState()
    }

    /// ◀キー。トグル入力中は1つ前の文字に戻す。
    public func cursorLeft() {
        beginKeyAction()
        if var current = toggle, composition.textBeforeCursor.hasSuffix(current.current) {
            let previous = current.current
            current.index = (current.index - 1 + current.cycle.count) % current.cycle.count
            current.time = now()
            toggle = current
            for _ in 0..<previous.count {
                composition.deleteBackward()
            }
            composition.insert(current.current)
            compositionChanged()
            return
        }
        moveCursor(by: -1)
    }

    /// ▶キー。トグル入力中は入力中の文字を確定させ、次の連打を新しい文字にする（標準キーボードの「→」と同じ）。
    public func cursorRight() {
        beginKeyAction()
        if toggle != nil {
            toggle = nil
            rebuildState()
            return
        }
        moveCursor(by: 1)
    }

    /// カーソル移動（空白キーのドラッグなど）。入力中は入力中の文字列の中で動かす。
    public func moveCursor(by offset: Int) {
        beginKeyAction()
        toggle = nil
        guard offset != 0 else { return }
        if !composition.isEmpty {
            if settings.usesMarkedText {
                selectedIndex = nil
                let flushed = flushRomaji()
                if composition.moveCursor(by: offset) != 0 || flushed {
                    compositionChanged()
                }
                return
            }
            // marked textを使わない場合は、入力中の文字列を確定してから動かす
            commitComposition()
        }
        clearIdleCandidates()
        moveDocumentCursor(by: offset)
        recordExpectedContext()
        rebuildState()
    }

    public func toggleShift() {
        let t = now()
        switch shift {
        case .off:
            shift = .once
        case .once:
            if let last = lastShiftTap, t.timeIntervalSince(last) < 0.35 {
                shift = .locked
            } else {
                shift = .off
            }
        case .locked:
            shift = .off
        }
        lastShiftTap = t
        rebuildState()
    }

    public func switchMode(to newMode: KeyboardMode) {
        setMode(newMode, commitComposition: newMode == .english)
        rebuildState()
    }

    /// 候補をタップした
    public func selectCandidate(at index: Int, requestID: Int) {
        guard requestID == candidateList.requestID, candidateList.candidates.indices.contains(index) else {
            return
        }
        toggle = nil
        let candidate = candidateList.candidates[index]
        if candidate.kind == .nextWord {
            guard composition.isEmpty, let document else { return }
            document.insertText(candidate.text)
            recordExpectedContext()
            conversion.commit(candidate, of: candidateList, remaining: "", options: conversionOptions)
            lastCommit = nil
            requestNextWord(after: candidate)
            rebuildState()
            return
        }
        if composition.isEmpty, let reconversion, let document {
            // 選択中のテキストを候補で置き換える
            document.insertText(candidate.text)
            recordExpectedContext()
            conversion.commit(candidate, of: candidateList, remaining: "", options: conversionOptions)
            self.reconversion = nil
            candidateList = .empty
            lastCommit = (candidate.text, reconversion.reading)
            rebuildState()
            return
        }
        guard !composition.isEmpty else { return }
        commit(candidate: candidate, continueComposing: false)
    }

    /// 候補の学習を取り消す（間違って覚えた候補を上位に出さないようにする）
    public func forgetCandidate(at index: Int, requestID: Int) {
        guard requestID == candidateList.requestID, candidateList.candidates.indices.contains(index) else {
            return
        }
        let candidate = candidateList.candidates[index]
        guard candidate.kind == .conversion else { return }
        conversion.forget(candidate, of: candidateList)
        // 並び順を更新するため、変換し直す
        if !composition.isEmpty, selectedIndex == nil {
            let source = conversionSource
            if !source.isEmpty {
                conversion.request(source: source, options: conversionOptions)
            }
        } else if let reconversion {
            conversion.request(source: reconversion.reading, options: conversionOptions)
        }
    }

    /// 直前に確定した文字列を読みに戻す（変換し直すため）
    public func undoLastCommit() {
        beginKeyAction()
        guard composition.isEmpty, let commit = lastCommit, let document,
              let before = document.documentContextBeforeInput, before.hasSuffix(commit.text) else {
            lastCommit = nil
            rebuildState()
            return
        }
        for _ in 0..<commit.text.count {
            document.deleteBackward()
        }
        lastCommit = nil
        toggle = nil
        composition = Composition(commit.reading)
        displayedPlainText = ""
        compositionChanged()
    }

    // MARK: - キーボード・入力欄のイベント

    /// 自分の操作に対する通知とみなす時間（秒）
    public var ownEditWindow: TimeInterval = 0.5

    /// ホストの入力欄が変化した（`textDidChange`・`selectionDidChange`）。
    ///
    /// 自分の操作による通知か、ユーザーが入力欄をタップしてカーソルを動かした等の外部の変更かを見分ける。
    /// - 自分の操作の直後（`ownEditWindow`以内）なら自分の操作とみなし、その時点の文脈を「期待する状態」として記録し直す。
    ///   `adjustTextPosition`などは文脈の更新が非同期なので、操作直後に読んだ値が古いことがあるため。
    /// - それ以外は外部の変更とみなし、入力中の状態を破棄する。
    public func documentDidChange() {
        let t = now()
        if let expected = expectedContext, t.timeIntervalSince(expected.time) < ownEditWindow {
            expectedContext = (document?.documentContextBeforeInput, document?.documentContextAfterInput, expected.time)
            return
        }
        if composition.isEmpty && displayedPlainText.isEmpty {
            // 入力中でなければ、予測候補と「取消」を消し、テキストが選択されていれば再変換の候補を出す
            clearIdleCandidates()
            lastCommit = nil
            updateAutoShift()
            updateReconversion()
            rebuildState()
            return
        }
        abandonComposition()
    }

    /// 選択中のテキストの読みを推定し、変換候補を出す
    private func updateReconversion() {
        reconversion = nil
        guard settings.reconversionEnabled, let document, let selected = document.selectedText, !selected.isEmpty,
              selected.count <= 30, !selected.contains(where: { $0.isNewline }),
              let reading = reading(for: selected), !reading.isEmpty, reading.count <= 40 else {
            return
        }
        reconversion = (selected, reading)
        conversion.request(source: reading, options: conversionOptions)
    }

    private func reading(for text: String) -> String? {
        if text.allSatisfy({ $0.isHiraganaForReading }) {
            return text
        }
        if text.allSatisfy({ $0.isKatakanaForReading }) {
            return text.katakanaToHiragana
        }
        return readingProvider?(text)?.katakanaToHiragana
    }

    /// キー操作の始めに呼ぶ
    private func beginKeyAction() {
        reconversion = nil
        verifyDocumentState()
    }

    /// キー入力の前に、入力欄が想定どおりの状態かを確かめる。
    /// 通知が届かないまま外部で変更されていた場合（入力欄をタップした等）、入力中の状態を破棄する。
    private func verifyDocumentState() {
        guard !composition.isEmpty || !displayedPlainText.isEmpty,
              let expected = expectedContext, now().timeIntervalSince(expected.time) >= ownEditWindow,
              let document, let before = document.documentContextBeforeInput, let expectedBefore = expected.before else {
            return
        }
        if before != expectedBefore || (document.documentContextAfterInput ?? "") != (expected.after ?? "") {
            abandonComposition()
        }
    }

    /// キーボードが閉じる・入力欄が切り替わる前に、入力中の文字列を確定する
    public func finishInput() {
        toggle = nil
        if flushRomaji() {
            render()
        }
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: false)
        } else if !composition.isEmpty {
            commitComposition()
        }
        clearIdleCandidates()
        lastCommit = nil
        conversion.flushLearning()
        rebuildState()
    }

    // MARK: - 内部処理

    private var conversionOptions: ConversionOptions {
        ConversionOptions(
            learningEnabled: settings.learningEnabled,
            predictionEnabled: settings.predictionEnabled,
            emojiCandidates: settings.emojiCandidates
        )
    }

    private func setMode(_ newMode: KeyboardMode, commitComposition shouldCommit: Bool) {
        toggle = nil
        if flushRomaji() {
            render()
        }
        if shouldCommit {
            if selectedIndex != nil {
                commitSelectedCandidate(continueComposing: false)
            } else if !composition.isEmpty {
                commitComposition()
            }
        }
        mode = newMode
        if newMode == .english {
            // 日本語の次の語の予測と「取消」は英字では使わないので消す
            clearIdleCandidates()
            lastCommit = nil
            updateAutoShift()
        } else {
            shift = .off
        }
    }

    /// 入力中でない状態で文字を直接入力する（英字・空白など）
    private func insertDirect(_ text: String) {
        toggle = nil
        if selectedIndex != nil {
            commitSelectedCandidate(continueComposing: false)
        } else if !composition.isEmpty {
            commitComposition()
        }
        clearIdleCandidates()
        lastCommit = nil
        document?.insertText(text)
        recordExpectedContext()
        rebuildState()
    }

    private func updateAutoShift() {
        guard mode == .english, settings.englishAutoCapitalization, shift != .locked else {
            return
        }
        let before = document?.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let atSentenceStart = trimmed.isEmpty || before.hasSuffix("\n")
            || ((trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")) && before.hasSuffix(" "))
        shift = atSentenceStart ? .once : .off
    }

    /// 入力中の文字列が変わったので、入力欄の表示と変換を更新する
    private func compositionChanged(requestConversion: Bool = true) {
        if composition.isEmpty {
            endComposition()
            return
        }
        render()
        if requestConversion {
            selectedIndex = nil
            let source = conversionSource
            if source.isEmpty {
                conversion.cancel()
                candidateList = .empty
            } else {
                conversion.request(source: source, options: conversionOptions)
            }
        }
        rebuildState()
    }

    /// 入力中の文字列（候補選択中は選択中の候補）を入力欄に表示する
    private func render() {
        guard let document else { return }
        let display: String
        let cursorUTF16: Int
        if let i = selectedIndex, candidateList.candidates.indices.contains(i) {
            let candidate = candidateList.candidates[i]
            let rest = String(composition.characters.dropFirst(candidate.consumedCount))
            display = candidate.text + rest
            cursorUTF16 = candidate.text.utf16.count
        } else {
            display = composition.text
            cursorUTF16 = composition.textBeforeCursor.utf16.count
        }
        if settings.usesMarkedText {
            document.setMarkedText(display, selectedRange: NSRange(location: cursorUTF16, length: 0))
        } else {
            replacePlainText(with: display)
        }
        recordExpectedContext()
    }

    /// marked textを使わない場合: 前回表示した文字列との差分だけを消して入れ直す
    private func replacePlainText(with display: String) {
        guard let document else { return }
        let old = Array(displayedPlainText)
        let new = Array(display)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] {
            common += 1
        }
        for _ in 0..<(old.count - common) {
            document.deleteBackward()
        }
        if common < new.count {
            document.insertText(String(new[common...]))
        }
        displayedPlainText = display
    }

    private func refreshCandidatesIfNeeded() {
        let source = conversionSource
        guard !source.isEmpty, candidateList.source != source || candidateList.requestID != conversion.latestRequestID else {
            return
        }
        candidateList = conversion.requestAndWait(source: source, options: conversionOptions)
    }

    private func receive(_ list: CandidateList) {
        if composition.isEmpty, let reconversion {
            guard list.source == reconversion.reading else { return }
            // 選択範囲全体を置き換えるので、読み全体を変換した候補だけを使う
            var filtered = list
            filtered.candidates = list.candidates.filter { $0.consumedCount == reconversion.reading.count && $0.text != reconversion.selected }
            candidateList = filtered
            rebuildState()
            return
        }
        if composition.isEmpty {
            // 次の語の予測（入力中でない時だけ表示）
            guard settings.nextWordPredictionEnabled, list.source.isEmpty else { return }
            candidateList = list
            rebuildState()
            return
        }
        guard selectedIndex == nil, list.source == conversionSource else {
            return
        }
        candidateList = list
        rebuildState()
    }

    private func commitSelectedCandidate(continueComposing: Bool) {
        guard let i = selectedIndex, candidateList.candidates.indices.contains(i) else {
            selectedIndex = nil
            return
        }
        commit(candidate: candidateList.candidates[i], continueComposing: continueComposing)
    }

    /// 候補を確定する。候補が入力の一部（先頭の文節）だけを置き換える場合は、残りを入力中のまま続ける。
    private func commit(candidate: ConversionCandidate, continueComposing: Bool) {
        guard let document else { return }
        // 候補が末尾の"n"まで使っている（「ん」として変換した）ときは、入力中の文字列も「ん」にしておく
        if candidate.consumedCount > composition.cursor - pendingRomaji().count {
            flushRomaji()
        }
        let consumed = max(0, min(candidate.consumedCount, composition.count))
        let reading = String(composition.characters.prefix(consumed))
        var remaining = composition
        remaining.removePrefix(consumed)
        if remaining.cursor == 0 {
            remaining.moveCursor(by: remaining.count)
        }
        conversion.commit(candidate, of: candidateList, remaining: remaining.text, options: conversionOptions)

        if settings.usesMarkedText {
            // marked text全体を候補で置き換え、残りを改めてmarked textにする
            document.insertText(candidate.text)
            if !remaining.isEmpty {
                document.setMarkedText(remaining.text, selectedRange: NSRange(location: remaining.textBeforeCursor.utf16.count, length: 0))
            }
        } else {
            replacePlainText(with: candidate.text + remaining.text)
            displayedPlainText = remaining.text
        }
        recordExpectedContext()
        lastCommit = remaining.isEmpty ? (candidate.text, reading) : nil
        selectedIndex = nil
        candidateList = .empty
        composition = remaining
        if composition.isEmpty {
            displayedPlainText = ""
            if !continueComposing {
                requestNextWord(after: candidate)
            } else {
                conversion.resetComposition()
            }
            rebuildState()
        } else {
            compositionChanged()
        }
    }

    /// 入力中の文字列をそのまま確定する
    private func commitComposition() {
        guard !composition.isEmpty else { return }
        if settings.usesMarkedText {
            document?.unmarkText()
        }
        recordExpectedContext()
        composition = Composition()
        selectedIndex = nil
        displayedPlainText = ""
        candidateList = .empty
        lastCommit = nil
        conversion.resetComposition()
    }

    private func endComposition() {
        if settings.usesMarkedText {
            document?.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            document?.unmarkText()
        } else {
            replacePlainText(with: "")
        }
        recordExpectedContext()
        composition = Composition()
        selectedIndex = nil
        displayedPlainText = ""
        candidateList = .empty
        conversion.resetComposition()
        rebuildState()
    }

    /// 入力欄が外部から変更されたので、状態を捨てる。
    /// ホスト側にmarked textが残っていると次の入力で上書きされて文字が消えるため、念のため確定させる
    /// （ホスト側ですでに確定済みなら何も起きない）。
    private func abandonComposition() {
        if settings.usesMarkedText {
            document?.unmarkText()
        }
        recordExpectedContext()
        composition = Composition()
        selectedIndex = nil
        toggle = nil
        displayedPlainText = ""
        candidateList = .empty
        lastCommit = nil
        conversion.resetComposition()
        rebuildState()
    }

    private func requestNextWord(after candidate: ConversionCandidate) {
        guard settings.nextWordPredictionEnabled else {
            conversion.resetComposition()
            return
        }
        conversion.requestNextWord(after: candidate, options: conversionOptions)
    }

    private func clearIdleCandidates() {
        guard composition.isEmpty, !candidateList.candidates.isEmpty else { return }
        conversion.cancel()
        candidateList = .empty
    }

    private func moveDocumentCursor(by count: Int) {
        guard let document else { return }
        var offset = 0
        if count > 0 {
            if let after = document.documentContextAfterInput, !after.isEmpty {
                offset = after.prefix(count).utf16.count
            } else {
                offset = count
            }
        } else {
            if let before = document.documentContextBeforeInput, !before.isEmpty {
                offset = -before.suffix(-count).utf16.count
            } else {
                offset = count
            }
        }
        document.adjustTextPosition(byCharacterOffset: offset)
    }

    private func recordExpectedContext() {
        expectedContext = (document?.documentContextBeforeInput, document?.documentContextAfterInput, now())
    }

    private func rebuildState() {
        var s = InputViewState()
        s.mode = mode
        s.isComposing = !composition.isEmpty
        s.candidates = candidateList.candidates
        s.candidateRequestID = candidateList.requestID
        s.selectedCandidateIndex = selectedIndex
        s.canUndoCommit = lastCommit != nil && composition.isEmpty && reconversion == nil
        s.isReconverting = reconversion != nil && !candidateList.candidates.isEmpty
        s.shift = shift
        s.isToggleActive = toggle != nil
        if mode == .english {
            s.spaceKeyLabel = "space"
            s.enterKeyLabel = returnKey.englishLabel
        } else if s.isComposing {
            s.spaceKeyLabel = selectedIndex == nil ? "変換" : "次候補"
            s.enterKeyLabel = "確定"
        } else {
            s.spaceKeyLabel = settings.spaceWidth == .full ? "全角空白" : "空白"
            s.enterKeyLabel = returnKey.label
        }
        s.enterKeyEmphasized = s.isComposing || returnKey != .default
        s.enterKeyDisabled = !s.isComposing && enablesReturnKeyAutomatically && !(document?.hasText ?? true)
        state = s
        onStateChange?(s)
    }
}

extension Character {
    var isHiraganaForReading: Bool {
        unicodeScalars.allSatisfy { (0x3041...0x3096).contains($0.value) || $0.value == 0x30FC }
    }

    var isKatakanaForReading: Bool {
        unicodeScalars.allSatisfy { (0x30A1...0x30F6).contains($0.value) || $0.value == 0x30FC }
    }
}

extension String {
    /// カタカナをひらがなにする（長音・その他の文字はそのまま）
    var katakanaToHiragana: String {
        String(String.UnicodeScalarView(unicodeScalars.map { scalar in
            if (0x30A1...0x30F6).contains(scalar.value), let h = Unicode.Scalar(scalar.value - 0x60) {
                return h
            }
            return scalar
        }))
    }
}
