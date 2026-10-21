#if canImport(UIKit)
import UIKit
import KeyFlowCore

public protocol CandidateBarDelegate: AnyObject {
    func candidateBar(_ bar: CandidateBarView, didSelect index: Int, requestID: Int)
    func candidateBarDidTapUndo(_ bar: CandidateBarView)
    func candidateBarDidTapExpand(_ bar: CandidateBarView)
    func candidateBarDidTapSettings(_ bar: CandidateBarView)
    func candidateBarDidTapDismiss(_ bar: CandidateBarView)
}

/// 候補1つ分のボタン
final class CandidateCell: UIControl {
    let label = UILabel()
    var index = 0
    var isSelectedCandidate = false {
        didSet { updateBackground() }
    }

    override var isHighlighted: Bool {
        didSet { updateBackground() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.textColor = KeyboardTheme.label
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 8, dy: 0)
    }

    private func updateBackground() {
        backgroundColor = (isSelectedCandidate || isHighlighted) ? KeyboardTheme.candidateSelected : .clear
    }
}

/// キーボード上部の変換候補バー。
///
/// 候補が無いときは「取消」と道具ボタン（設定・キーボードを閉じる）を表示する。
public final class CandidateBarView: UIView {
    public weak var delegate: (any CandidateBarDelegate)?

    private let scrollView = UIScrollView()
    private var cells: [CandidateCell] = []
    private var candidates: [ConversionCandidate] = []
    private var requestID = -1
    private var selectedIndex: Int?
    private let expandButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let separator = UIView()
    /// 選択中のテキストを変換し直していることを示すラベル
    private let reconversionLabel = UILabel()
    public var fontSize: CGFloat = 17 {
        didSet { if oldValue != fontSize { setNeedsLayout() } }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.candidateBar
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.delaysContentTouches = false
        addSubview(scrollView)

        func setup(_ b: UIButton, _ image: String, _ label: String, _ action: Selector) {
            b.setImage(UIImage(systemName: image, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)), for: .normal)
            b.tintColor = KeyboardTheme.secondaryLabel
            b.accessibilityLabel = label
            b.addTarget(self, action: action, for: .touchUpInside)
            addSubview(b)
        }
        setup(expandButton, "chevron.down", "候補をすべて表示", #selector(tapExpand))
        setup(settingsButton, "slider.horizontal.3", "キーボードの調整", #selector(tapSettings))
        setup(dismissButton, "keyboard.chevron.compact.down", "キーボードを閉じる", #selector(tapDismiss))

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.uturn.backward", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        config.imagePadding = 4
        config.title = "取消"
        config.baseForegroundColor = KeyboardTheme.label
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        undoButton.configuration = config
        undoButton.accessibilityLabel = "直前の確定を取り消して変換し直す"
        undoButton.addTarget(self, action: #selector(tapUndo), for: .touchUpInside)
        addSubview(undoButton)

        separator.backgroundColor = KeyboardTheme.separator
        addSubview(separator)

        reconversionLabel.text = "再変換"
        reconversionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        reconversionLabel.textColor = KeyboardTheme.secondaryLabel
        reconversionLabel.isHidden = true
        addSubview(reconversionLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func apply(state: InputViewState) {
        let changed = state.candidates != candidates || state.candidateRequestID != requestID
        candidates = state.candidates
        requestID = state.candidateRequestID
        let selectionChanged = state.selectedCandidateIndex != selectedIndex
        selectedIndex = state.selectedCandidateIndex
        undoButton.isHidden = !state.canUndoCommit
        reconversionLabel.isHidden = !state.isReconverting
        if changed {
            reloadCells()
            scrollView.setContentOffset(.zero, animated: false)
        } else if selectionChanged {
            updateSelection()
        }
        setNeedsLayout()
    }

    private func reloadCells() {
        while cells.count < candidates.count {
            let cell = CandidateCell()
            cell.addTarget(self, action: #selector(tapCandidate(_:)), for: .touchUpInside)
            scrollView.addSubview(cell)
            cells.append(cell)
        }
        for (i, cell) in cells.enumerated() {
            if i < candidates.count {
                cell.isHidden = false
                cell.index = i
                cell.label.text = candidates[i].text
                cell.label.font = .systemFont(ofSize: fontSize, weight: i == 0 ? .medium : .regular)
                cell.isSelectedCandidate = i == selectedIndex
            } else {
                cell.isHidden = true
            }
        }
    }

    private func updateSelection() {
        for (i, cell) in cells.enumerated() where i < candidates.count {
            cell.isSelectedCandidate = i == selectedIndex
        }
        if let selectedIndex, selectedIndex < cells.count {
            scrollView.scrollRectToVisible(cells[selectedIndex].frame.insetBy(dx: -24, dy: 0), animated: true)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let buttonWidth: CGFloat = 40
        separator.frame = CGRect(x: 0, y: h - 0.5, width: bounds.width, height: 0.5)

        let hasCandidates = !candidates.isEmpty
        expandButton.isHidden = !hasCandidates
        settingsButton.isHidden = hasCandidates
        dismissButton.isHidden = hasCandidates

        var right = bounds.width
        if hasCandidates {
            expandButton.frame = CGRect(x: right - buttonWidth, y: 0, width: buttonWidth, height: h)
            right -= buttonWidth
        } else {
            dismissButton.frame = CGRect(x: right - buttonWidth, y: 0, width: buttonWidth, height: h)
            right -= buttonWidth
            settingsButton.frame = CGRect(x: right - buttonWidth, y: 0, width: buttonWidth, height: h)
            right -= buttonWidth
        }
        var left: CGFloat = 4
        if !reconversionLabel.isHidden {
            let size = reconversionLabel.sizeThatFits(CGSize(width: 80, height: h))
            reconversionLabel.frame = CGRect(x: left + 4, y: (h - size.height) / 2, width: size.width, height: size.height)
            left += size.width + 10
        }
        if !undoButton.isHidden {
            let size = undoButton.sizeThatFits(CGSize(width: 120, height: h))
            undoButton.frame = CGRect(x: left, y: (h - size.height) / 2, width: size.width, height: size.height)
            left += size.width + 4
        }
        scrollView.frame = CGRect(x: left, y: 0, width: max(right - left, 0), height: h)

        var x: CGFloat = 0
        let font = UIFont.systemFont(ofSize: fontSize)
        for (i, cell) in cells.enumerated() where i < candidates.count {
            let textWidth = (candidates[i].text as NSString).size(withAttributes: [.font: font]).width
            let w = min(max(ceil(textWidth) + 20, 44), scrollView.bounds.width)
            cell.frame = CGRect(x: x, y: 3, width: w, height: h - 6)
            x += w + 2
        }
        scrollView.contentSize = CGSize(width: x, height: h)
    }

    @objc private func tapCandidate(_ sender: CandidateCell) {
        delegate?.candidateBar(self, didSelect: sender.index, requestID: requestID)
    }

    @objc private func tapUndo() {
        delegate?.candidateBarDidTapUndo(self)
    }

    @objc private func tapExpand() {
        delegate?.candidateBarDidTapExpand(self)
    }

    @objc private func tapSettings() {
        delegate?.candidateBarDidTapSettings(self)
    }

    @objc private func tapDismiss() {
        delegate?.candidateBarDidTapDismiss(self)
    }
}

/// 候補をすべて表示する一覧（キー領域に重ねて表示する）
public final class CandidateGridView: UIView {
    public var onSelect: ((Int, Int) -> Void)?
    public var onClose: (() -> Void)?

    private let scrollView = UIScrollView()
    private let closeButton = UIButton(type: .system)
    private var cells: [CandidateCell] = []
    private var candidates: [ConversionCandidate] = []
    private var requestID = -1
    public var fontSize: CGFloat = 17

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        addSubview(scrollView)
        closeButton.setImage(UIImage(systemName: "chevron.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)), for: .normal)
        closeButton.tintColor = KeyboardTheme.secondaryLabel
        closeButton.accessibilityLabel = "候補一覧を閉じる"
        closeButton.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show(candidates: [ConversionCandidate], requestID: Int) {
        self.candidates = candidates
        self.requestID = requestID
        while cells.count < candidates.count {
            let cell = CandidateCell()
            cell.addTarget(self, action: #selector(tapCandidate(_:)), for: .touchUpInside)
            cell.layer.borderWidth = 0.5
            cell.layer.borderColor = KeyboardTheme.separator.resolvedColor(with: traitCollection).cgColor
            scrollView.addSubview(cell)
            cells.append(cell)
        }
        for (i, cell) in cells.enumerated() {
            cell.isHidden = i >= candidates.count
            if i < candidates.count {
                cell.index = i
                cell.label.text = candidates[i].text
                cell.label.font = .systemFont(ofSize: fontSize)
            }
        }
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let buttonWidth: CGFloat = 44
        closeButton.frame = CGRect(x: bounds.width - buttonWidth, y: 0, width: buttonWidth, height: 40)
        scrollView.frame = CGRect(x: 4, y: 0, width: bounds.width - buttonWidth - 4, height: bounds.height)
        // 文字幅に合わせて左から詰め、行からはみ出したら折り返す
        let font = UIFont.systemFont(ofSize: fontSize)
        let rowHeight: CGFloat = 44
        let maxWidth = scrollView.bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 2
        for (i, cell) in cells.enumerated() where i < candidates.count {
            let textWidth = (candidates[i].text as NSString).size(withAttributes: [.font: font]).width
            let w = min(max(ceil(textWidth) + 24, 52), maxWidth)
            if x + w > maxWidth, x > 0 {
                x = 0
                y += rowHeight + 4
            }
            cell.frame = CGRect(x: x, y: y, width: w, height: rowHeight)
            x += w + 4
        }
        scrollView.contentSize = CGSize(width: maxWidth, height: y + rowHeight + 8)
    }

    @objc private func tapCandidate(_ sender: CandidateCell) {
        onSelect?(sender.index, requestID)
    }

    @objc private func tapClose() {
        onClose?()
    }
}
#endif
