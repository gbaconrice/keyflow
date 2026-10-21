import SwiftUI
import KeyFlowCore
import KeyFlowKeyboardUI

/// プレビュー用の変換エンジン。アプリには辞書を入れていないため、ひらがな・カタカナの候補だけを返す。
final class PreviewEngine: ConversionEngine {
    func candidates(for source: String, requestID: Int, options: ConversionOptions) -> CandidateList {
        let katakana = source.applyingTransform(.hiraganaToKatakana, reverse: false) ?? source
        var texts = [source]
        if katakana != source {
            texts.append(katakana)
        }
        let candidates = texts.enumerated().map { i, t in
            ConversionCandidate(text: t, consumedCount: source.count, engineIndex: i)
        }
        return CandidateList(requestID: requestID, source: source, candidates: candidates)
    }

    func commit(_ candidate: ConversionCandidate, of list: CandidateList, remaining: String, options: ConversionOptions) {}

    func nextWordCandidates(after committed: ConversionCandidate, requestID: Int, options: ConversionOptions) -> CandidateList {
        CandidateList(requestID: requestID, source: "", candidates: [])
    }

    func resetComposition() {}
    func flushLearning() {}
    func resetLearning() {}
    func updateUserDictionary(_ entries: [UserDictionaryEntry]) {}
}

/// プレビューで打った文字列の状態
struct PreviewSnapshot: Equatable {
    var text = ""
    var markedRange: Range<Int>?
    var cursor = 0

    var isEmpty: Bool { text.isEmpty }

    /// 入力中の部分に下線を付け、カーソル位置に縦線を入れた表示
    var rendered: Text {
        let chars = Array(text)
        var result = Text("")
        var i = 0
        while i <= chars.count {
            if i == cursor {
                result = result + Text("|").foregroundColor(.accentColor)
            }
            guard i < chars.count else { break }
            if let r = markedRange, r.lowerBound == i {
                let end = min(r.upperBound, chars.count)
                // 下線部の途中にカーソルがある場合も考えて、カーソルの前後で分ける
                if cursor > i && cursor < end {
                    result = result + Text(String(chars[i..<cursor])).underline()
                    result = result + Text("|").foregroundColor(.accentColor)
                    result = result + Text(String(chars[cursor..<end])).underline()
                } else {
                    result = result + Text(String(chars[i..<end])).underline()
                }
                i = end
                continue
            }
            result = result + Text(String(chars[i]))
            i += 1
        }
        return result
    }
}

/// 設定画面の下に表示するキーボードのプレビュー。実際のキーボードと同じ部品で描画し、打った結果をその場で確認できる。
struct KeyboardPreviewPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var snapshot = PreviewSnapshot()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Group {
                    if snapshot.isEmpty {
                        Text("ここで試し打ちできます").foregroundStyle(.secondary)
                    } else {
                        snapshot.rendered
                    }
                }
                .font(.body)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("消去") {
                    NotificationCenter.default.post(name: .keyFlowPreviewClear, object: nil)
                }
                .font(.footnote)
                .disabled(snapshot.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
            KeyboardPreview(settings: model.settings, snapshot: $snapshot) { newSettings in
                model.settings = newSettings
            }
            .frame(height: CGFloat(model.settings.candidateBarHeight + model.settings.portraitKeyAreaHeight))
        }
    }
}

extension Notification.Name {
    static let keyFlowPreviewClear = Notification.Name("KeyFlowPreviewClear")
}

struct KeyboardPreview: UIViewRepresentable {
    var settings: KeyboardSettings
    @Binding var snapshot: PreviewSnapshot
    var onSettingsChange: (KeyboardSettings) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings)
    }

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator
        coordinator.onTyped = { newSnapshot in
            snapshot = newSnapshot
        }
        coordinator.session.onSettingsChange = { s in
            onSettingsChange(s)
        }
        return coordinator.session.rootView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.session.updateSettings(settings)
    }

    final class Coordinator {
        let field = SimulatedTextField()
        let session: KeyboardSession
        var onTyped: ((PreviewSnapshot) -> Void)?
        private var observer: NSObjectProtocol?

        init(settings: KeyboardSettings) {
            let queue = ConversionQueue(engine: PreviewEngine(), scheduler: ImmediateTaskScheduler())
            let controller = InputController(settings: settings, conversion: queue)
            controller.document = field
            session = KeyboardSession(controller: controller, settings: settings)
            session.onStateChange = { [weak self] _ in
                self?.publish()
            }
            observer = NotificationCenter.default.addObserver(forName: .keyFlowPreviewClear, object: nil, queue: .main) { [weak self] _ in
                self?.clear()
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func clear() {
            session.controller.finishInput()
            field.reset()
            publish()
        }

        private func publish() {
            onTyped?(PreviewSnapshot(text: field.text, markedRange: field.markedRange, cursor: field.cursor))
        }
    }
}
