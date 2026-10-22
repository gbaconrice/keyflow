import Foundation

/// 処理を実行するスレッドの抽象。テストでは同期実行に差し替える。
public protocol TaskScheduler: AnyObject {
    func runInBackground(_ work: @escaping () -> Void)
    func runOnMain(_ work: @escaping () -> Void)
    func runInBackgroundAndWait<T>(_ work: () -> T) -> T
}

/// 直列のバックグラウンドキューで実行する本番用の実装
public final class DispatchTaskScheduler: TaskScheduler {
    private let queue = DispatchQueue(label: "keyflow.conversion", qos: .userInitiated)

    public init() {}

    public func runInBackground(_ work: @escaping () -> Void) {
        let box = UncheckedSendableBox(work)
        queue.async { box.value() }
    }

    public func runOnMain(_ work: @escaping () -> Void) {
        let box = UncheckedSendableBox(work)
        DispatchQueue.main.async { box.value() }
    }

    public func runInBackgroundAndWait<T>(_ work: () -> T) -> T {
        queue.sync(execute: work)
    }
}

/// 直列キューで排他されることを前提に、Sendableでない値をキューへ渡すための箱
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// その場で実行するテスト用の実装
public final class ImmediateTaskScheduler: TaskScheduler {
    public init() {}
    public func runInBackground(_ work: @escaping () -> Void) { work() }
    public func runOnMain(_ work: @escaping () -> Void) { work() }
    public func runInBackgroundAndWait<T>(_ work: () -> T) -> T { work() }
}

/// 変換エンジンへのアクセスを直列化し、キー入力（メインスレッド）を止めないようにする。
///
/// - 変換要求は最新のものだけを処理する（連打中に溜まった古い要求は捨てる）
/// - 結果はメインスレッドに返し、その時点で最新の要求に対するものでなければ捨てる
/// - 学習の更新も同じキューで順番に処理する
public final class ConversionQueue {
    private let engine: any ConversionEngine
    private let scheduler: any TaskScheduler
    private let lock = NSLock()
    private var pending: (id: Int, source: String, options: ConversionOptions)?
    /// メインスレッドからのみ触る
    private(set) public var latestRequestID = 0

    /// 要求IDはプロセス全体で重ならないように振る。
    /// キーボードを表示し直すと、同じエンジンを新しいキューから使うため（エンジンは直近の結果をIDで照合する）。
    private static let idLock = NSLock()
    nonisolated(unsafe) private static var lastIssuedID = 0

    @discardableResult
    private func issueRequestID() -> Int {
        Self.idLock.lock()
        defer { Self.idLock.unlock() }
        Self.lastIssuedID += 1
        latestRequestID = Self.lastIssuedID
        return latestRequestID
    }

    /// 変換結果（メインスレッドで呼ばれる）
    public var onCandidates: ((CandidateList) -> Void)?

    public init(engine: any ConversionEngine, scheduler: any TaskScheduler) {
        self.engine = engine
        self.scheduler = scheduler
    }

    /// 変換を非同期に要求する
    @discardableResult
    public func request(source: String, options: ConversionOptions) -> Int {
        let id = issueRequestID()
        lock.lock()
        pending = (id, source, options)
        lock.unlock()
        scheduler.runInBackground { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let job = self.pending
            self.pending = nil
            self.lock.unlock()
            guard let job else {
                // 後続の要求にまとめて処理された
                return
            }
            let result = self.engine.candidates(for: job.source, requestID: job.id, options: job.options)
            self.scheduler.runOnMain { [weak self] in
                guard let self, result.requestID == self.latestRequestID else { return }
                self.onCandidates?(result)
            }
        }
        return id
    }

    /// 変換結果がすぐに必要な場合（結果が届く前に「次候補」を押した場合など）
    public func requestAndWait(source: String, options: ConversionOptions) -> CandidateList {
        let id = issueRequestID()
        lock.lock()
        pending = nil
        lock.unlock()
        return scheduler.runInBackgroundAndWait {
            engine.candidates(for: source, requestID: id, options: options)
        }
    }

    /// 確定後の次の語の候補を非同期に要求する
    public func requestNextWord(after candidate: ConversionCandidate, options: ConversionOptions) {
        let id = issueRequestID()
        lock.lock()
        pending = nil
        lock.unlock()
        scheduler.runInBackground { [weak self] in
            guard let self else { return }
            let result = self.engine.nextWordCandidates(after: candidate, requestID: id, options: options)
            self.scheduler.runOnMain { [weak self] in
                guard let self, result.requestID == self.latestRequestID else { return }
                self.onCandidates?(result)
            }
        }
    }

    /// 処理待ちの要求を取り消し、届く予定の結果も捨てる
    public func cancel() {
        issueRequestID()
        lock.lock()
        pending = nil
        lock.unlock()
    }

    public func commit(_ candidate: ConversionCandidate, of list: CandidateList, remaining: String, options: ConversionOptions) {
        scheduler.runInBackground { [engine] in
            engine.commit(candidate, of: list, remaining: remaining, options: options)
        }
    }

    public func forget(_ candidate: ConversionCandidate, of list: CandidateList) {
        scheduler.runInBackground { [engine] in
            engine.forget(candidate, of: list)
        }
    }

    public func resetComposition() {
        cancel()
        scheduler.runInBackground { [engine] in
            engine.resetComposition()
        }
    }

    public func flushLearning() {
        scheduler.runInBackground { [engine] in
            engine.flushLearning()
        }
    }

    public func resetLearning() {
        scheduler.runInBackground { [engine] in
            engine.resetLearning()
        }
    }

    public func updateUserDictionary(_ entries: [UserDictionaryEntry]) {
        scheduler.runInBackground { [engine] in
            engine.updateUserDictionary(entries)
        }
    }

    /// エンジンを直接使う処理（初期化時のウォームアップなど）
    public func perform(_ work: @escaping (any ConversionEngine) -> Void) {
        scheduler.runInBackground { [engine] in
            work(engine)
        }
    }
}
