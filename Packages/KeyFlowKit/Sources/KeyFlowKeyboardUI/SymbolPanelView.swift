#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// 記号・顔文字の一覧（キー領域に重ねて表示する）。選んだ文字列はすぐに入力され、一覧は開いたままにする。
public final class SymbolPanelView: UIView {
    public var onInsert: ((String) -> Void)?
    public var onDelete: (() -> Void)?
    public var onClose: (() -> Void)?

    static let symbols: [String] = [
        "、", "。", "，", "．", "・", "：", "；", "？", "！", "ー", "〜", "…",
        "「", "」", "『", "』", "（", "）", "【", "】", "［", "］", "〈", "〉",
        "＋", "－", "×", "÷", "＝", "≠", "＜", "＞", "±", "％", "＃", "＆",
        "＊", "＠", "￥", "＄", "／", "＼", "｜", "＿", "＾", "°", "℃", "※",
        "→", "←", "↑", "↓", "☆", "★", "○", "●", "◎", "△", "□", "♪",
        "〒", "々", "〆", "♂", "♀", "∞", "∴", "♡", "✓", "§", "¶", "†",
    ]

    static let kaomoji: [String] = [
        "(^^)", "(^_^)", "(*^^*)", "(^o^)", "(^-^)", "(^^;", "(^_^;)", "(>_<)",
        "(;_;)", "(T_T)", "(´・ω・`)", "(・∀・)", "(￣▽￣)", "(*´ω`*)", "(｀・ω・´)", "(≧∇≦)",
        "\\(^o^)/", "ヽ(*´∀`)ノ", "(´；ω；`)", "(・_・;)", "m(_ _)m", "(_ _)", "(=^・^=)", "( ˘ω˘ )",
        "┐(´д`)┌", "(*_*)", "(o^^o)", "(￣ー￣)", "(´-ω-`)", "(*'▽')", "(｡･ω･｡)", "orz",
    ]

    private let tabs = UISegmentedControl(items: ["記号", "顔文字"])
    private let scrollView = UIScrollView()
    private let deleteButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var buttons: [UIButton] = []
    private var items: [String] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background
        tabs.selectedSegmentIndex = 0
        tabs.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        addSubview(tabs)
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        addSubview(scrollView)
        deleteButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        deleteButton.tintColor = KeyboardTheme.label
        deleteButton.accessibilityLabel = "削除"
        deleteButton.addTarget(self, action: #selector(tapDelete), for: .touchUpInside)
        addSubview(deleteButton)
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        closeButton.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        addSubview(closeButton)
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reload() {
        items = tabs.selectedSegmentIndex == 0 ? Self.symbols : Self.kaomoji
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.enumerated().map { i, text in
            let b = UIButton(type: .custom)
            b.setTitle(text, for: .normal)
            b.setTitleColor(KeyboardTheme.label, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: tabs.selectedSegmentIndex == 0 ? 20 : 15)
            b.backgroundColor = KeyboardTheme.key
            b.layer.cornerRadius = 6
            b.tag = i
            b.addTarget(self, action: #selector(tapItem(_:)), for: .touchUpInside)
            scrollView.addSubview(b)
            return b
        }
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = 40
        tabs.frame = CGRect(x: 8, y: 6, width: min(200, bounds.width * 0.5), height: barHeight - 12)
        closeButton.frame = CGRect(x: bounds.width - 70, y: 0, width: 66, height: barHeight)
        deleteButton.frame = CGRect(x: bounds.width - 120, y: 0, width: 48, height: barHeight)
        scrollView.frame = CGRect(x: 4, y: barHeight, width: bounds.width - 8, height: bounds.height - barHeight)

        let isSymbol = tabs.selectedSegmentIndex == 0
        let gap: CGFloat = 5
        let height: CGFloat = 40
        let width = scrollView.bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 2
        if isSymbol {
            // 記号は同じ幅で格子状に並べる
            let columns = max(Int((width + gap) / (44 + gap)), 6)
            let w = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            for (i, b) in buttons.enumerated() {
                let col = i % columns
                let row = i / columns
                b.frame = CGRect(x: CGFloat(col) * (w + gap), y: y + CGFloat(row) * (height + gap), width: w, height: height)
            }
            let rows = (buttons.count + columns - 1) / columns
            scrollView.contentSize = CGSize(width: width, height: y + CGFloat(rows) * (height + gap))
        } else {
            // 顔文字は文字幅に合わせて詰める
            for b in buttons {
                let w = min(max((b.titleLabel?.intrinsicContentSize.width ?? 40) + 20, 56), width)
                if x + w > width, x > 0 {
                    x = 0
                    y += height + gap
                }
                b.frame = CGRect(x: x, y: y, width: w, height: height)
                x += w + gap
            }
            scrollView.contentSize = CGSize(width: width, height: y + height + gap)
        }
    }

    @objc private func tabChanged() {
        reload()
    }

    @objc private func tapItem(_ sender: UIButton) {
        guard items.indices.contains(sender.tag) else { return }
        onInsert?(items[sender.tag])
    }

    @objc private func tapDelete() {
        onDelete?()
    }

    @objc private func tapClose() {
        onClose?()
    }
}
#endif
