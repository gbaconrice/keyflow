#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// キー1つ分の表示。タッチは親の`KeyboardView`がまとめて処理する。
final class KeyCapView: UIView {
    enum Style {
        case normal
        case functional
        case accent
    }

    private let capView = UIView()
    private let titleLabel = UILabel()
    /// フリック先の文字（小さく四隅に表示）
    private let hintLabels: [FlickDirection: UILabel] = [
        .left: UILabel(), .up: UILabel(), .right: UILabel(), .down: UILabel(),
    ]
    private let subLabel = UILabel()
    private let iconView = UIImageView()

    private(set) var style: Style = .normal
    var isPressed = false {
        didSet { if oldValue != isPressed { updateColors() } }
    }
    var isEnabled = true {
        didSet { if oldValue != isEnabled { updateColors() } }
    }
    var cornerRadius: CGFloat = 7 {
        didSet { capView.layer.cornerRadius = cornerRadius }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        capView.layer.cornerRadius = cornerRadius
        capView.layer.cornerCurve = .continuous
        capView.layer.shadowOffset = CGSize(width: 0, height: 1)
        capView.layer.shadowRadius = 0
        capView.layer.shadowOpacity = 1
        addSubview(capView)

        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.baselineAdjustment = .alignCenters
        capView.addSubview(titleLabel)

        for label in hintLabels.values {
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 9, weight: .regular)
            label.textColor = KeyboardTheme.secondaryLabel
            label.isHidden = true
            capView.addSubview(label)
        }
        subLabel.textAlignment = .center
        subLabel.font = .systemFont(ofSize: 10, weight: .regular)
        subLabel.textColor = KeyboardTheme.secondaryLabel
        subLabel.adjustsFontSizeToFitWidth = true
        subLabel.minimumScaleFactor = 0.6
        subLabel.isHidden = true
        capView.addSubview(subLabel)

        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = true
        capView.addSubview(iconView)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String?, systemImage: String? = nil, fontSize: CGFloat, style: Style, hints: [FlickDirection: String] = [:], subtitle: String? = nil) {
        self.style = style
        if let systemImage {
            iconView.image = UIImage(systemName: systemImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize * 0.8, weight: .regular))
            iconView.isHidden = false
            titleLabel.isHidden = true
        } else {
            iconView.isHidden = true
            titleLabel.isHidden = false
            titleLabel.text = title
            let isLong = (title?.count ?? 0) > 2
            titleLabel.font = .systemFont(ofSize: isLong ? min(fontSize, 16) : fontSize, weight: .regular)
        }
        for (direction, label) in hintLabels {
            if let hint = hints[direction] {
                label.text = hint
                label.isHidden = false
            } else {
                label.isHidden = true
            }
        }
        if let subtitle {
            subLabel.text = subtitle
            subLabel.isHidden = false
        } else {
            subLabel.isHidden = true
        }
        updateColors()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capView.frame = bounds
        let b = capView.bounds
        let hasSub = !subLabel.isHidden
        if hasSub {
            titleLabel.frame = CGRect(x: 2, y: b.height * 0.08, width: b.width - 4, height: b.height * 0.58)
            subLabel.frame = CGRect(x: 2, y: b.height * 0.62, width: b.width - 4, height: b.height * 0.3)
        } else {
            titleLabel.frame = b.insetBy(dx: 3, dy: 2)
        }
        iconView.frame = b.insetBy(dx: b.width * 0.25, dy: b.height * 0.22)
        let hintSize: CGFloat = 12
        hintLabels[.left]?.frame = CGRect(x: 3, y: (b.height - hintSize) / 2, width: hintSize, height: hintSize)
        hintLabels[.right]?.frame = CGRect(x: b.width - hintSize - 3, y: (b.height - hintSize) / 2, width: hintSize, height: hintSize)
        hintLabels[.up]?.frame = CGRect(x: (b.width - hintSize) / 2, y: 2, width: hintSize, height: hintSize)
        hintLabels[.down]?.frame = CGRect(x: (b.width - hintSize) / 2, y: b.height - hintSize - 2, width: hintSize, height: hintSize)
        capView.layer.shadowPath = UIBezierPath(roundedRect: b, cornerRadius: cornerRadius).cgPath
        capView.layer.shadowColor = KeyboardTheme.keyShadow.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        capView.layer.shadowColor = KeyboardTheme.keyShadow.resolvedColor(with: traitCollection).cgColor
    }

    private func updateColors() {
        let background: UIColor
        let foreground: UIColor
        switch style {
        case .normal:
            background = isPressed ? KeyboardTheme.keyPressed : KeyboardTheme.key
            foreground = KeyboardTheme.label
        case .functional:
            background = isPressed ? KeyboardTheme.functionalKeyPressed : KeyboardTheme.functionalKey
            foreground = KeyboardTheme.label
        case .accent:
            if isEnabled {
                background = isPressed ? KeyboardTheme.accentKeyPressed : KeyboardTheme.accentKey
                foreground = KeyboardTheme.accentLabel
            } else {
                background = KeyboardTheme.functionalKey
                foreground = KeyboardTheme.disabledLabel
            }
        }
        capView.backgroundColor = background
        titleLabel.textColor = isEnabled ? foreground : KeyboardTheme.disabledLabel
        iconView.tintColor = isEnabled ? foreground : KeyboardTheme.disabledLabel
    }
}
#endif
