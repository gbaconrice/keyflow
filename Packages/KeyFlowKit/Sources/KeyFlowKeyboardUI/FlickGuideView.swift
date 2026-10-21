#if canImport(UIKit)
import UIKit
import KeyFlowCore

/// フリック入力中に、入力される文字を吹き出しで示す。
/// 長押しすると5方向すべてを十字に表示する。
final class FlickGuideView: UIView {
    private var cells: [FlickDirection: UILabel] = [:]
    private var outputs: [FlickDirection: String] = [:]
    private var keyFrame: CGRect = .zero
    private var showsAll = false
    private var active: FlickDirection = .center

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for direction in FlickDirection.allCases {
            let label = UILabel()
            label.textAlignment = .center
            label.layer.cornerRadius = 8
            label.layer.cornerCurve = .continuous
            label.layer.masksToBounds = true
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.isHidden = true
            addSubview(label)
            cells[direction] = label
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - keyFrame: 対象キーの矩形（このビューの親の座標）
    ///   - showsAll: 5方向すべてを表示する
    func show(outputs: [FlickDirection: String], keyFrame: CGRect, active: FlickDirection, showsAll: Bool, fontSize: CGFloat) {
        self.outputs = outputs
        self.keyFrame = keyFrame
        self.active = active
        self.showsAll = showsAll
        isHidden = false
        for (direction, label) in cells {
            guard let text = outputs[direction], showsAll || direction == active, !(direction == .center && !showsAll) else {
                label.isHidden = true
                continue
            }
            label.isHidden = false
            label.text = text
            let isActive = direction == active
            label.font = .systemFont(ofSize: isActive ? fontSize * 1.25 : fontSize, weight: isActive ? .semibold : .regular)
            label.backgroundColor = isActive ? KeyboardTheme.popupActive : KeyboardTheme.popup
            label.textColor = isActive ? .white : KeyboardTheme.label
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    func hide() {
        isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = keyFrame.width
        let h = keyFrame.height
        for (direction, label) in cells {
            var f = keyFrame
            switch direction {
            case .center: break
            case .left: f.origin.x -= w
            case .right: f.origin.x += w
            case .up: f.origin.y -= h
            case .down: f.origin.y += h
            }
            // 吹き出しは少し大きめにして指に隠れにくくする
            label.frame = convert(f, from: superview).insetBy(dx: -2, dy: -2)
        }
    }
}

/// 英字キーを押したときに、キーの上に大きく文字を表示する
final class KeyPreviewView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = KeyboardTheme.popup
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.35
        layer.shadowColor = UIColor.black.cgColor
        label.textAlignment = .center
        label.textColor = KeyboardTheme.label
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(text: String, above keyFrame: CGRect, fontSize: CGFloat) {
        label.text = text
        label.font = .systemFont(ofSize: fontSize * 1.4, weight: .regular)
        let width = max(keyFrame.width * 1.3, 40)
        let height = keyFrame.height * 1.15
        frame = CGRect(x: keyFrame.midX - width / 2, y: keyFrame.minY - height - 4, width: width, height: height)
        label.frame = bounds
        isHidden = false
    }

    func hide() {
        isHidden = true
    }
}
#endif
