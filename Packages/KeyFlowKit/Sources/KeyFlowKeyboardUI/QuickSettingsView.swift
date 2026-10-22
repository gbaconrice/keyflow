#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// キーボード上で直接調整できる項目（よく変えるものだけ）。
/// 変更はすぐにキーボードへ反映され、キーボード側に保存される。
public final class QuickSettingsView: UIView {
    public var onChange: ((KeyboardSettings) -> Void)?
    public var onClose: (() -> Void)?

    private var settings: KeyboardSettings
    private var isLandscape: Bool
    private var hasFullAccess: Bool
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let heightSlider = UISlider()
    private let heightValue = UILabel()
    private let oneHanded = UISegmentedControl(items: ["左手", "オフ", "右手"])
    private let flickSlider = UISlider()
    private let flickValue = UILabel()
    private let toggleSwitch = UISwitch()
    private let hapticSwitch = UISwitch()
    private let spaceControl = UISegmentedControl(items: ["半角", "全角"])
    private let kanaLayoutControl = UISegmentedControl(items: ["12キー", "ローマ字"])

    public init(settings: KeyboardSettings, isLandscape: Bool, hasFullAccess: Bool) {
        self.settings = settings
        self.isLandscape = isLandscape
        self.hasFullAccess = hasFullAccess
        super.init(frame: .zero)
        backgroundColor = KeyboardTheme.background
        build()
        load()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let header = UIStackView()
        header.axis = .horizontal
        let title = UILabel()
        title.text = "キーボードの調整"
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = KeyboardTheme.label
        let done = UIButton(type: .system)
        done.setTitle("完了", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        done.addTarget(self, action: #selector(close), for: .touchUpInside)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(done)

        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 14, bottom: 12, right: 14)
        stack.addArrangedSubview(header)

        kanaLayoutControl.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row("日本語の配列", kanaLayoutControl, nil))

        heightSlider.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row(isLandscape ? "高さ（横画面）" : "高さ", heightSlider, heightValue))

        oneHanded.addTarget(self, action: #selector(changed), for: .valueChanged)
        oneHanded.isEnabled = !isLandscape
        stack.addArrangedSubview(row("片手モード", oneHanded, nil))

        flickSlider.minimumValue = Float(KeyboardSettings.Ranges.flickThreshold.lowerBound)
        flickSlider.maximumValue = Float(KeyboardSettings.Ranges.flickThreshold.upperBound)
        flickSlider.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row("フリックの判定距離", flickSlider, flickValue))

        toggleSwitch.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row("連打で文字を切り替える", toggleSwitch, nil))

        spaceControl.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row("空白", spaceControl, nil))

        hapticSwitch.addTarget(self, action: #selector(changed), for: .valueChanged)
        stack.addArrangedSubview(row("振動", hapticSwitch, nil))
        if !hasFullAccess {
            let note = UILabel()
            note.text = "振動を使うには、設定アプリでフルアクセスをオンにしてください。"
            note.font = .systemFont(ofSize: 11)
            note.textColor = KeyboardTheme.secondaryLabel
            note.numberOfLines = 0
            stack.addArrangedSubview(note)
        }

        scrollView.addSubview(stack)
        addSubview(scrollView)
    }

    private func row(_ title: String, _ control: UIView, _ value: UILabel?) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14)
        label.textColor = KeyboardTheme.label
        label.setContentHuggingPriority(.required, for: .horizontal)
        let h = UIStackView(arrangedSubviews: [label, control])
        h.axis = .horizontal
        h.spacing = 12
        h.alignment = .center
        if let value {
            value.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            value.textColor = KeyboardTheme.secondaryLabel
            value.textAlignment = .right
            value.widthAnchor.constraint(equalToConstant: 48).isActive = true
            h.addArrangedSubview(value)
        }
        return h
    }

    private func load() {
        let range = isLandscape ? KeyboardSettings.Ranges.landscapeKeyAreaHeight : KeyboardSettings.Ranges.portraitKeyAreaHeight
        heightSlider.minimumValue = Float(range.lowerBound)
        heightSlider.maximumValue = Float(range.upperBound)
        heightSlider.value = Float(isLandscape ? settings.landscapeKeyAreaHeight : settings.portraitKeyAreaHeight)
        switch settings.oneHandedMode {
        case .left: oneHanded.selectedSegmentIndex = 0
        case .off: oneHanded.selectedSegmentIndex = 1
        case .right: oneHanded.selectedSegmentIndex = 2
        }
        flickSlider.value = Float(settings.flickThreshold)
        toggleSwitch.isOn = settings.toggleInputEnabled
        spaceControl.selectedSegmentIndex = settings.spaceWidth == .half ? 0 : 1
        hapticSwitch.isOn = settings.hapticFeedback
        kanaLayoutControl.selectedSegmentIndex = settings.kanaLayout == .flick ? 0 : 1
        updateValueLabels()
    }

    private func updateValueLabels() {
        heightValue.text = "\(Int(heightSlider.value.rounded()))"
        flickValue.text = "\(Int(flickSlider.value.rounded()))"
    }

    @objc private func changed() {
        let height = Double(heightSlider.value.rounded())
        if isLandscape {
            settings.landscapeKeyAreaHeight = height
        } else {
            settings.portraitKeyAreaHeight = height
        }
        switch oneHanded.selectedSegmentIndex {
        case 0: settings.oneHandedMode = .left
        case 2: settings.oneHandedMode = .right
        default: settings.oneHandedMode = .off
        }
        settings.flickThreshold = Double(flickSlider.value.rounded())
        settings.toggleInputEnabled = toggleSwitch.isOn
        settings.spaceWidth = spaceControl.selectedSegmentIndex == 0 ? .half : .full
        settings.hapticFeedback = hapticSwitch.isOn
        settings.kanaLayout = kanaLayoutControl.selectedSegmentIndex == 0 ? .flick : .romaji
        updateValueLabels()
        onChange?(settings)
    }

    @objc private func close() {
        onClose?()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        let size = stack.systemLayoutSizeFitting(CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        stack.frame = CGRect(x: 0, y: 0, width: bounds.width, height: size.height)
        scrollView.contentSize = CGSize(width: bounds.width, height: size.height)
    }
}
#endif
