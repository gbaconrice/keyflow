import SwiftUI
import KeyFlowCore

extension UserDictionaryEntry.Category {
    var title: String {
        switch self {
        case .noun: "一般の名詞"
        case .personName: "人名"
        case .placeName: "地名"
        case .organization: "組織・団体名"
        case .phrase: "定型文・その他"
        }
    }
}

struct UserDictionaryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: UserDictionaryEntry?
    @State private var adding = false

    private var sorted: [UserDictionaryEntry] {
        model.userDictionary.sorted { $0.reading < $1.reading }
    }

    var body: some View {
        List {
            if !model.isSharedAvailable {
                Section {
                    Text("署名の設定により、アプリとキーボードの間でデータを共有できません。登録した単語はキーボードに反映されません。")
                        .foregroundStyle(.orange)
                }
            }
            if model.userDictionary.isEmpty {
                Section {
                    Text("よく使う名前や用語を登録すると、変換候補に出るようになります。右上の＋から追加してください。")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(sorted) { entry in
                        Button {
                            editing = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.word).foregroundStyle(.primary)
                                Text("\(entry.reading)・\(entry.category.title)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { sorted[$0].id }
                        model.userDictionary.removeAll { ids.contains($0.id) }
                    }
                } footer: {
                    Text("\(model.userDictionary.count)語。次にキーボードを開いたときに反映されます。")
                }
            }
            Section {
                Toggle("iPhoneのユーザ辞書も使う", isOn: $model.settings.systemLexiconEnabled)
            } footer: {
                Text("「設定」→「一般」→「キーボード」→「ユーザ辞書」に登録した単語も変換候補に出します。読みがひらがなかカタカナのものだけが対象です。フルアクセスは不要です。")
            }
        }
        .navigationTitle("ユーザー辞書")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("単語を追加")
            }
        }
        .sheet(isPresented: $adding) {
            EntryEditor(entry: nil) { entry in
                model.userDictionary.append(entry)
            }
        }
        .sheet(item: $editing) { entry in
            EntryEditor(entry: entry) { updated in
                if let i = model.userDictionary.firstIndex(where: { $0.id == updated.id }) {
                    model.userDictionary[i] = updated
                }
            }
        }
    }
}

private struct EntryEditor: View {
    let entry: UserDictionaryEntry?
    let onSave: (UserDictionaryEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var word = ""
    @State private var reading = ""
    @State private var category = UserDictionaryEntry.Category.noun

    private var trimmedReading: String {
        reading.trimmingCharacters(in: .whitespaces)
    }

    /// 読みはひらがな（長音・小書き・濁点付きを含む）だけを受け付ける
    private var readingError: String? {
        guard !trimmedReading.isEmpty else { return nil }
        let ok = trimmedReading.unicodeScalars.allSatisfy { (0x3041...0x3096).contains($0.value) || $0.value == 0x30FC }
        return ok ? nil : "よみはひらがなで入力してください。"
    }

    private var canSave: Bool {
        !word.trimmingCharacters(in: .whitespaces).isEmpty && !trimmedReading.isEmpty && readingError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("単語（例: 鍵流）", text: $word)
                    TextField("よみ（例: きーふろー）", text: $reading)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let readingError {
                        Text(readingError).foregroundStyle(.red)
                    }
                }
                Section {
                    Picker("品詞", selection: $category) {
                        ForEach(UserDictionaryEntry.Category.allCases, id: \.self) { c in
                            Text(c.title).tag(c)
                        }
                    }
                } footer: {
                    Text("文の中での使われ方に近いものを選ぶと、前後とつながりやすくなります。")
                }
            }
            .navigationTitle(entry == nil ? "単語を追加" : "単語を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var e = entry ?? UserDictionaryEntry(word: "", reading: "")
                        e.word = word.trimmingCharacters(in: .whitespaces)
                        e.reading = trimmedReading
                        e.category = category
                        onSave(e)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let entry {
                    word = entry.word
                    reading = entry.reading
                    category = entry.category
                }
            }
        }
    }
}
