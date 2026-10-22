import UIKit
import KeyFlowCore
import KeyFlowEngine
import KeyFlowKeyboardUI

/// `UITextDocumentProxy`を入力状態管理用の`TextDocument`として見せる
final class ProxyTextDocument: TextDocument {
    private weak var inputViewController: UIInputViewController?

    init(inputViewController: UIInputViewController) {
        self.inputViewController = inputViewController
    }

    private var proxy: (any UITextDocumentProxy)? { inputViewController?.textDocumentProxy }

    var documentContextBeforeInput: String? { proxy?.documentContextBeforeInput }
    var documentContextAfterInput: String? { proxy?.documentContextAfterInput }
    var selectedText: String? { proxy?.selectedText }
    var hasText: Bool { proxy?.hasText ?? false }

    func insertText(_ text: String) { proxy?.insertText(text) }
    func deleteBackward() { proxy?.deleteBackward() }
    func adjustTextPosition(byCharacterOffset offset: Int) { proxy?.adjustTextPosition(byCharacterOffset: offset) }
    func setMarkedText(_ text: String, selectedRange: NSRange) { proxy?.setMarkedText(text, selectedRange: selectedRange) }
    func unmarkText() { proxy?.unmarkText() }
}

/// 変換エンジンはプロセスに1つだけ置く。
///
/// iOSはキーボードを表示するたびに新しい`KeyboardViewController`を作るが、拡張のプロセスは使い回す。
/// そのたびにエンジンを作ると辞書の準備をやり直すうえ、古いものが解放されるまでメモリが重複する。
/// 変換はすべて同じ直列キュー（`scheduler`）で行うので、複数のコントローラーから使ってもエンジンへのアクセスは直列になる。
/// メインスレッドからのみ触る。
private enum SharedConversion {
    static let scheduler = DispatchTaskScheduler()
    private static var engine: AzooKeyEngine?
    /// 最後に読み込んだユーザー辞書（同じ内容を読み込み直さないため）
    static var userDictionaryFingerprint: Int?
    /// iPhoneの「ユーザ辞書」から取り込んだ単語
    static var systemLexiconEntries: [UserDictionaryEntry] = []
    /// iPhoneの「ユーザ辞書」の英字の短縮形（小文字の短縮形 → 置き換える文字列）
    static var englishShortcuts: [String: String] = [:]
    /// 英単語の補完（端末内の辞書を使う）
    static let textChecker = UITextChecker()

    /// 英字で打っている途中の単語の候補。短縮形を先に、続けて補完、補完が少なければつづりの候補を出す。
    static func suggestions(for word: String) -> [String] {
        var result: [String] = []
        if let expanded = englishShortcuts[word.lowercased()] {
            result.append(expanded)
        }
        let range = NSRange(location: 0, length: word.utf16.count)
        let language = "en_US"
        result += (textChecker.completions(forPartialWordRange: range, in: word, language: language) ?? []).prefix(6)
        // 補完が少なく、つづりが辞書にないときは、つづりの候補も出す
        if result.count < 3, word.count >= 3,
           textChecker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language).location != NSNotFound {
            result += (textChecker.guesses(forWordRange: range, in: word, language: language) ?? []).prefix(3)
        }
        return result
    }

    /// 共有のエンジン。初めて作ったときは`isNew`がtrue。
    static func engine(store: SettingsStore, versionString: String) -> (engine: AzooKeyEngine, isNew: Bool) {
        if let engine {
            return (engine, false)
        }
        // 学習データはキーボード自身の領域に置く（フルアクセスなしではApp Groupに書き込めないため）
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let memoryDirectory = library.appendingPathComponent("KeyFlowLearning", isDirectory: true)
        let created = AzooKeyEngine(memoryDirectory: memoryDirectory, sharedDirectory: store.sharedContainerURL, versionString: versionString)
        engine = created
        return (created, true)
    }
}

final class KeyboardViewController: UIInputViewController {
    private var session: KeyboardSession?
    private var conversion: ConversionQueue?
    private var store: SettingsStore?
    private var heightConstraint: NSLayoutConstraint?
    private var lastDocumentIdentifier: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        let store = SettingsStore.resolved()
        self.store = store
        let settings = store.loadEffectiveSettings()

        let (engine, isNew) = SharedConversion.engine(store: store, versionString: "KeyFlow \(Self.appVersion)")
        let conversion = ConversionQueue(engine: engine, scheduler: SharedConversion.scheduler)
        self.conversion = conversion
        if isNew {
            conversion.perform { engine in
                (engine as? AzooKeyEngine)?.warmUp()
            }
        } else {
            // 前の表示で入力途中だった状態が残らないようにする
            conversion.resetComposition()
        }

        let controller = InputController(settings: settings, conversion: conversion)
        controller.document = ProxyTextDocument(inputViewController: self)
        controller.readingProvider = { JapaneseReading.reading(of: $0) }
        controller.wordSuggester = { SharedConversion.suggestions(for: $0) }
        let session = KeyboardSession(controller: controller, settings: settings)
        session.onSettingsChange = { [weak self] s in
            self?.store?.saveLocalSettings(s)
        }
        session.onDismiss = { [weak self] in
            self?.session?.controller.finishInput()
            self?.dismissKeyboard()
        }
        session.onHeightChange = { [weak self] in
            self?.updateHeight()
        }
        session.rootView.keyboardView.globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        self.session = session

        let root = session.rootView
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // システムが付ける高さ制約とぶつからないよう、優先度を1つ下げる
        let height = view.heightAnchor.constraint(equalToConstant: session.preferredHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        reloadUserDictionaryIfNeeded()
        if store.consumeLearningResetRequest() {
            conversion.resetLearning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let session, let store else { return }
        session.updateSettings(store.loadEffectiveSettings())
        session.hasFullAccess = hasFullAccess
        loadSystemLexicon()
        reloadUserDictionaryIfNeeded()
        if store.consumeLearningResetRequest() {
            conversion?.resetLearning()
        }
        updateOrientationAndGlobe()
        configureForCurrentField()
        updateHeight()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 画面端の近くのキーで、システムのジェスチャー判定のためにタッチの開始が遅れるのを防ぐ
        var current: UIView? = view
        while let v = current {
            v.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
            current = v.superview
        }
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.controller.finishInput()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateOrientationAndGlobe()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateOrientationAndGlobe()
        updateHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updateOrientationAndGlobe()
            self?.updateHeight()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        conversion?.perform { $0.purgeMemory() }
    }

    // MARK: - 入力欄の変化

    override func textWillChange(_ textInput: (any UITextInput)?) {
        super.textWillChange(textInput)
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        let identifier = textDocumentProxy.documentIdentifier
        if identifier != lastDocumentIdentifier {
            lastDocumentIdentifier = identifier
            session?.controller.documentDidChange()
            configureForCurrentField()
        } else {
            session?.controller.documentDidChange()
        }
    }

    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        session?.controller.documentDidChange()
    }

    // MARK: - 内部処理

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func updateOrientationAndGlobe() {
        guard let session else { return }
        session.isLandscape = traitCollection.verticalSizeClass == .compact
        session.showsGlobeKey = needsInputModeSwitchKey
    }

    private func updateHeight() {
        guard let session, let heightConstraint else { return }
        let target = session.preferredHeight
        if abs(heightConstraint.constant - target) > 0.5 {
            heightConstraint.constant = target
        }
    }

    private func configureForCurrentField() {
        guard let session else { return }
        let proxy = textDocumentProxy
        let returnKey: ReturnKeyKind
        switch proxy.returnKeyType ?? .default {
        case .go: returnKey = .go
        case .google, .yahoo, .search: returnKey = .search
        case .send: returnKey = .send
        case .done: returnKey = .done
        case .next: returnKey = .next
        case .join: returnKey = .join
        case .route: returnKey = .route
        case .continue: returnKey = .continue
        case .emergencyCall: returnKey = .emergencyCall
        default: returnKey = .default
        }
        let fieldKind: InputFieldKind
        switch proxy.keyboardType ?? .default {
        case .URL, .webSearch: fieldKind = .url
        case .emailAddress: fieldKind = .email
        case .asciiCapable, .asciiCapableNumberPad, .twitter: fieldKind = .ascii
        case .numberPad, .decimalPad, .numbersAndPunctuation: fieldKind = .number
        default: fieldKind = .normal
        }
        session.controller.configure(
            returnKey: returnKey,
            enablesReturnKeyAutomatically: proxy.enablesReturnKeyAutomatically ?? false,
            fieldKind: fieldKind
        )
        // 入力欄がダークの外観を求めていればそれに合わせる
        session.rootView.overrideUserInterfaceStyle = proxy.keyboardAppearance == .dark ? .dark : .unspecified
    }

    /// iPhoneの「ユーザ辞書」を読み込む（フルアクセスなしで読める）。表示のたびに読み直し、追加された単語も反映する。
    private func loadSystemLexicon() {
        guard store?.loadEffectiveSettings().systemLexiconEnabled ?? true else {
            SharedConversion.systemLexiconEntries = []
            SharedConversion.englishShortcuts = [:]
            return
        }
        requestSupplementaryLexicon { [weak self] lexicon in
            let pairs = lexicon.entries.map { (input: $0.userInput, text: $0.documentText) }
            let entries = SystemLexicon.userDictionaryEntries(from: pairs)
            let shortcuts = SystemLexicon.englishShortcuts(from: pairs)
            DispatchQueue.main.async {
                SharedConversion.systemLexiconEntries = entries
                SharedConversion.englishShortcuts = shortcuts
                self?.reloadUserDictionaryIfNeeded()
            }
        }
    }

    private func reloadUserDictionaryIfNeeded() {
        guard let store, let conversion else { return }
        let entries = store.loadUserDictionary() + SharedConversion.systemLexiconEntries
        // IDは読み込むたびに変わることがあるので、読み・単語・品詞だけで比べる
        var hasher = Hasher()
        for entry in entries {
            hasher.combine(entry.reading)
            hasher.combine(entry.word)
            hasher.combine(entry.category)
        }
        let fingerprint = hasher.finalize()
        guard fingerprint != SharedConversion.userDictionaryFingerprint else { return }
        SharedConversion.userDictionaryFingerprint = fingerprint
        conversion.updateUserDictionary(entries)
    }
}
