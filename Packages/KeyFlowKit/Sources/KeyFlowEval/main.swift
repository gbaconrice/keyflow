import Foundation
import KeyFlowCore
import KeyFlowEngine

// 変換精度と応答時間の評価。
//
// 使い方: swift run -c release KeyFlowEval <corpus.tsv>
//
// - 1文字打つごとに変換する実際のキーボードと同じ流れで、各打鍵の変換時間を測る
// - 最後まで打った時点で、「変換」キーで選べる候補（予測を除く）の何位に正解があるかを数える
// - 1回正解を確定した後にもう一度変換し、学習で順位が上がるかを確かめる

#if os(Linux) || os(macOS)
struct Row {
    let reading: String
    let answers: [String]
    let category: String
}

func load(_ path: String) -> [Row] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
        exit(1)
    }
    return text.split(separator: "\n").compactMap { line in
        if line.hasPrefix("#") || line.isEmpty { return nil }
        let cols = line.split(separator: "\t").map(String.init)
        guard cols.count >= 3 else { return nil }
        return Row(reading: cols[0], answers: cols[1].split(separator: "|").map(String.init), category: cols[2])
    }
}

func peakMemoryMB() -> Double {
    #if os(Linux)
    if let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) {
        for line in status.split(separator: "\n") where line.hasPrefix("VmHWM:") {
            let kb = line.split(separator: " ").compactMap { Double($0) }.first ?? 0
            return kb / 1024
        }
    }
    return 0
    #else
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_maxrss) / 1024 / 1024
    #endif
}

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))
    return sorted[index]
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: KeyFlowEval <corpus.tsv>")
    exit(1)
}
let rows = load(args[1])
let memory = FileManager.default.temporaryDirectory.appendingPathComponent("keyflow-eval-\(UUID().uuidString)")
let engine = AzooKeyEngine(memoryDirectory: memory)
let options = ConversionOptions()

let startup = Date()
engine.warmUp()
let warmUpTime = Date().timeIntervalSince(startup)

var keystrokeTimes: [Double] = []
/// 時間のかかった打鍵（入力途中の読みと時間）
var slowKeystrokes: [(input: String, ms: Double)] = []
var stats: [String: (n: Int, top1: Int, top3: Int, top10: Int, learned: Int)] = [:]
var misses: [String] = []
var requestID = 0

for row in rows {
    engine.resetComposition()
    let chars = Array(row.reading)
    var final = CandidateList.empty
    for i in 1...chars.count {
        requestID += 1
        let t = Date()
        final = engine.candidates(for: String(chars[0..<i]), requestID: requestID, options: options)
        let ms = Date().timeIntervalSince(t) * 1000
        keystrokeTimes.append(ms)
        slowKeystrokes.append((String(chars[0..<i]), ms))
    }
    let conversions = final.candidates.filter { !$0.isPrediction && $0.consumedCount == chars.count }
    let rank = conversions.firstIndex { row.answers.contains($0.text) }

    // 学習の効果: 正解を1回確定してから同じ読みを変換し直す
    var learned = false
    if let rank, rank > 0 {
        let target = conversions[rank]
        engine.commit(target, of: final, remaining: "", options: options)
        requestID += 1
        let again = engine.candidates(for: row.reading, requestID: requestID, options: options)
        learned = again.candidates.first { !$0.isPrediction }?.text == target.text
    } else if rank == 0 {
        learned = true
    }

    for key in [row.category, "ALL"] {
        var s = stats[key] ?? (0, 0, 0, 0, 0)
        s.n += 1
        if rank == 0 { s.top1 += 1 }
        if let rank, rank < 3 { s.top3 += 1 }
        if let rank, rank < 10 { s.top10 += 1 }
        if learned { s.learned += 1 }
        stats[key] = s
    }
    if rank != 0 {
        let top = conversions.prefix(3).map(\.text).joined(separator: " / ")
        misses.append("- [\(row.category)] \(row.reading) → 期待: \(row.answers[0]) / 結果: \(top) / 正解の順位: \(rank.map { "\($0 + 1)" } ?? "圏外")")
    }
}

func pct(_ a: Int, _ n: Int) -> String {
    n == 0 ? "-" : String(format: "%.0f%%", Double(a) / Double(n) * 100)
}

print("## 変換精度（\(rows.count)文）\n")
print("| 分類 | 件数 | 1位 | 3位以内 | 10位以内 | 1回学習後に1位 |")
print("|---|---|---|---|---|---|")
for key in stats.keys.sorted(by: { ($0 == "ALL" ? 1 : 0, $0) < ($1 == "ALL" ? 1 : 0, $1) }) {
    let s = stats[key]!
    print("| \(key) | \(s.n) | \(pct(s.top1, s.n)) | \(pct(s.top3, s.n)) | \(pct(s.top10, s.n)) | \(pct(s.learned, s.n)) |")
}
print("\n## 応答時間（1打鍵ごとの変換, \(keystrokeTimes.count)回）\n")
print(String(format: "- 平均 %.1f ms / 中央値 %.1f ms / 95%%点 %.1f ms / 最大 %.1f ms", keystrokeTimes.reduce(0, +) / Double(max(keystrokeTimes.count, 1)), percentile(keystrokeTimes, 0.5), percentile(keystrokeTimes, 0.95), keystrokeTimes.max() ?? 0))
print(String(format: "- 初回の準備（warmUp）: %.0f ms", warmUpTime * 1000))
print(String(format: "- プロセスの最大メモリ使用量: %.1f MB", peakMemoryMB()))
let slowest = slowKeystrokes.sorted { $0.ms > $1.ms }.prefix(5)
print("- 時間のかかった打鍵: " + slowest.map { String(format: "%@ %.0f ms", $0.input, $0.ms) }.joined(separator: " / "))
print("\n## 1位で正解しなかった例\n")
misses.forEach { print($0) }
try? FileManager.default.removeItem(at: memory)
#else
// iOSなどでは使わない（パッケージ全体をビルドするときのために空の実行ファイルにする）
print("KeyFlowEval runs on Linux or macOS")
#endif
