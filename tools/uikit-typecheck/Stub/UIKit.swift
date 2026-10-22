// 型検査用の最小限のUIKitスタブ（Linux専用・実行はしない）。シグネチャは公開SDKに合わせる。
@_exported import Foundation
public struct Selector: ExpressibleByStringLiteral { public init(stringLiteral value: String) {}; public init(_ s: String) {} }

open class NSCoder {}
public struct UILayoutPriority: RawRepresentable, Equatable {
    public var rawValue: Float
    public init(rawValue: Float) { self.rawValue = rawValue }
    public init(_ rawValue: Float) { self.rawValue = rawValue }
    public static let required = UILayoutPriority(1000)
    public static let defaultHigh = UILayoutPriority(750)
    public static let fittingSizeLevel = UILayoutPriority(50)
}
public struct UIEdgeInsets { public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {} }
public struct NSDirectionalEdgeInsets { public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {} }
public enum UIUserInterfaceStyle: Int { case unspecified, light, dark }
public enum UIUserInterfaceSizeClass: Int { case unspecified, compact, regular }
open class UITraitCollection: NSObject {
    open var userInterfaceStyle: UIUserInterfaceStyle { .light }
    open var verticalSizeClass: UIUserInterfaceSizeClass { .regular }
}
public class CGColorStub {}
public typealias CGColor = CGColorStub
open class UIColor: NSObject {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(dynamicProvider: @escaping (UITraitCollection) -> UIColor) {}
    open func resolvedColor(with traitCollection: UITraitCollection) -> UIColor { self }
    open var cgColor: CGColor { CGColor() }
    public static var white: UIColor { UIColor(red: 1, green: 1, blue: 1, alpha: 1) }
    public static var black: UIColor { UIColor(red: 0, green: 0, blue: 0, alpha: 1) }
    public static var clear: UIColor { UIColor(red: 0, green: 0, blue: 0, alpha: 0) }
}
public enum CALayerCornerCurve { case circular, continuous }
public class CGPathStub {}
open class CALayer: NSObject {
    open var cornerRadius: CGFloat = 0
    open var cornerCurve: CALayerCornerCurve = .circular
    open var shadowOffset: CGSize = .zero
    open var shadowRadius: CGFloat = 0
    open var shadowOpacity: Float = 0
    open var shadowColor: CGColor?
    open var shadowPath: CGPathStub?
    open var masksToBounds = false
    open var borderWidth: CGFloat = 0
    open var borderColor: CGColor?
    open var frame: CGRect = .zero
    open var mask: CALayer?
}
open class CAGradientLayer: CALayer {
    open var colors: [Any]?
    open var locations: [NSNumber]?
    open var startPoint: CGPoint = .zero
    open var endPoint: CGPoint = .zero
}
open class CATransaction: NSObject {
    open class func begin() {}
    open class func commit() {}
    open class func setDisableActions(_ flag: Bool) {}
}
open class UIBezierPath: NSObject {
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat) {}
    open var cgPath: CGPathStub { CGPathStub() }
}
open class UIFont: NSObject {
    public struct Weight { public static let regular = Weight(); public static let medium = Weight(); public static let semibold = Weight(); public static let bold = Weight() }
    open class func systemFont(ofSize: CGFloat, weight: Weight) -> UIFont { UIFont() }
    open class func systemFont(ofSize: CGFloat) -> UIFont { UIFont() }
    open class func monospacedDigitSystemFont(ofSize: CGFloat, weight: Weight) -> UIFont { UIFont() }
}
public enum NSLayoutConstraintAxis { case horizontal, vertical }
open class NSLayoutDimension {
    open func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
}
open class NSLayoutXAxisAnchor { open func constraint(equalTo: NSLayoutXAxisAnchor) -> NSLayoutConstraint { NSLayoutConstraint() } }
open class NSLayoutYAxisAnchor { open func constraint(equalTo: NSLayoutYAxisAnchor) -> NSLayoutConstraint { NSLayoutConstraint() } }
open class NSLayoutConstraint: NSObject {
    open var constant: CGFloat = 0
    open var priority: UILayoutPriority = .required
    open var isActive = false
    open class func activate(_ c: [NSLayoutConstraint]) {}
}
open class UIResponder: NSObject {
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}
open class UIEvent: NSObject {}
open class UITouch: NSObject { open func location(in view: UIView?) -> CGPoint { .zero }; open var timestamp: TimeInterval { 0 } }
public enum UIAccessibilityTraitsEnum {}
public struct UIAccessibilityTraits: OptionSet { public let rawValue: UInt64; public init(rawValue: UInt64) { self.rawValue = rawValue }; public static let keyboardKey = UIAccessibilityTraits(rawValue: 1) }
open class UIAccessibilityElement: NSObject {
    public init(accessibilityContainer container: Any) {}
    open var accessibilityFrameInContainerSpace: CGRect = .zero
    open var accessibilityLabel: String?
    open var accessibilityIdentifier: String?
    open var accessibilityTraits: UIAccessibilityTraits = []
    open func accessibilityActivate() -> Bool { false }
}
public enum UIContentMode { case scaleAspectFit, scaleToFill }
public enum UIViewAutoresizing {}
open class UIView: UIResponder {
    public init(frame: CGRect) {}
    public required init?(coder: NSCoder) {}
    public convenience override init() { self.init(frame: .zero) }
    open var frame: CGRect = .zero
    open var bounds: CGRect = .zero
    open var backgroundColor: UIColor?
    open var isHidden = false
    open var isUserInteractionEnabled = true
    open var isMultipleTouchEnabled = false
    open var isExclusiveTouch = false
    open var clipsToBounds = false
    open var layer: CALayer { CALayer() }
    open var superview: UIView?
    open var subviews: [UIView] { [] }
    open var traitCollection: UITraitCollection { UITraitCollection() }
    open var overrideUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    open var tintColor: UIColor!
    open var contentMode: UIContentMode = .scaleToFill
    open var translatesAutoresizingMaskIntoConstraints = true
    open var gestureRecognizers: [UIGestureRecognizer]?
    open var window: UIWindow?
    open var accessibilityLabel: String?
    open var accessibilityIdentifier: String?
    open var accessibilityElements: [Any]?
    open var tag = 0
    open var intrinsicContentSize: CGSize { .zero }
    open var widthAnchor: NSLayoutDimension { NSLayoutDimension() }
    open var heightAnchor: NSLayoutDimension { NSLayoutDimension() }
    open var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    open var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    open var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
    open var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
    open func addSubview(_ v: UIView) {}
    open func addGestureRecognizer(_ g: UIGestureRecognizer) {}
    open func insertSubview(_ v: UIView, at: Int) {}
    open func removeFromSuperview() {}
    open func layoutSubviews() {}
    open func setNeedsLayout() {}
    open func layoutIfNeeded() {}
    open func sizeThatFits(_ size: CGSize) -> CGSize { .zero }
    open func convert(_ rect: CGRect, from view: UIView?) -> CGRect { rect }
    open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
    open func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority h: UILayoutPriority, verticalFittingPriority v: UILayoutPriority) -> CGSize { .zero }
    public static let layoutFittingCompressedSize = CGSize.zero
}
open class UIWindow: UIView {}
public enum UIGestureRecognizerState { case possible, began, changed, ended, cancelled, failed }
open class UIGestureRecognizer: NSObject {
    public typealias State = UIGestureRecognizerState
    public init(target: Any?, action: Selector?) {}
    open var delaysTouchesBegan = true
    open var state: UIGestureRecognizerState { .possible }
    open var view: UIView? { nil }
}
open class UILongPressGestureRecognizer: UIGestureRecognizer { open var minimumPressDuration: TimeInterval = 0.5 }
public enum NSTextAlignment { case left, center, right, natural }
public enum NSLineBreakMode { case byTruncatingTail, byWordWrapping }
public enum UIBaselineAdjustment { case alignCenters, none }
open class UILabel: UIView {
    open var text: String?
    open var font: UIFont!
    open var textColor: UIColor!
    open var textAlignment: NSTextAlignment = .natural
    open var adjustsFontSizeToFitWidth = false
    open var minimumScaleFactor: CGFloat = 0
    open var baselineAdjustment: UIBaselineAdjustment = .none
    open var numberOfLines = 1
    open var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    open func setContentHuggingPriority(_ p: UILayoutPriority, for axis: NSLayoutConstraintAxis) {}
}
public class UIImageSymbolConfiguration {
    public init(pointSize: CGFloat, weight: UIFont.Weight) {}
    public init(pointSize: CGFloat) {}
}
open class UIImage: NSObject {
    public typealias SymbolConfiguration = UIImageSymbolConfiguration
    public init?(systemName: String) {}
    public init?(systemName: String, withConfiguration: UIImageSymbolConfiguration?) {}
}
open class UIImageView: UIView { open var image: UIImage? }
public struct UIControlEvents: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let touchUpInside = UIControlEvents(rawValue: 1); public static let valueChanged = UIControlEvents(rawValue: 2); public static let allTouchEvents = UIControlEvents(rawValue: 4) }
public struct UIControlState: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let normal = UIControlState(rawValue: 0) }
open class UIControl: UIView {
    public typealias Event = UIControlEvents
    public typealias State = UIControlState
    open var isHighlighted = false
    open var isEnabled = true
    open func addTarget(_ target: Any?, action: Selector, for events: UIControlEvents) {}
}
public enum UIButtonType { case custom, system }
public struct UIButtonConfiguration {
    public static func plain() -> UIButtonConfiguration { UIButtonConfiguration() }
    public var image: UIImage?
    public var imagePadding: CGFloat = 0
    public var title: String?
    public var baseForegroundColor: UIColor?
    public var contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}
open class UIButton: UIControl {
    public typealias Configuration = UIButtonConfiguration
    public convenience init(type: UIButtonType) { self.init(frame: .zero) }
    open var configuration: UIButtonConfiguration?
    open var titleLabel: UILabel?
    open func setImage(_ image: UIImage?, for state: UIControlState) {}
    open func setTitle(_ title: String?, for state: UIControlState) {}
    open func setTitleColor(_ color: UIColor?, for state: UIControlState) {}
}
public protocol UIScrollViewDelegate: AnyObject {
    func scrollViewDidScroll(_ scrollView: UIScrollView)
}
public extension UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {}
}
open class UIScrollView: UIView {
    open var showsHorizontalScrollIndicator = true
    open var alwaysBounceHorizontal = false
    open var alwaysBounceVertical = false
    open var delaysContentTouches = true
    open var contentSize: CGSize = .zero
    open var contentOffset: CGPoint = .zero
    open weak var delegate: (any UIScrollViewDelegate)?
    open func setContentOffset(_ p: CGPoint, animated: Bool) {}
    open func scrollRectToVisible(_ r: CGRect, animated: Bool) {}
}
public enum UIStackViewAlignment { case fill, center, leading }
public enum UIStackViewDistribution { case fill, equalSpacing }
open class UIStackView: UIView {
    public convenience init(arrangedSubviews: [UIView]) { self.init(frame: .zero) }
    public override init(frame: CGRect) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(frame: .zero) }
    open var axis: NSLayoutConstraintAxis = .horizontal
    open var alignment: UIStackViewAlignment = .fill
    open var distribution: UIStackViewDistribution = .fill
    open var spacing: CGFloat = 0
    open var isLayoutMarginsRelativeArrangement = false
    open var layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    open var arrangedSubviews: [UIView] { [] }
    open func addArrangedSubview(_ v: UIView) {}
}
open class UISlider: UIControl { open var value: Float = 0; open var minimumValue: Float = 0; open var maximumValue: Float = 1 }
open class UISwitch: UIControl { open var isOn = false }
open class UISegmentedControl: UIControl {
    public convenience init(items: [Any]?) { self.init(frame: .zero) }
    public override init(frame: CGRect) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(frame: .zero) }
    open var selectedSegmentIndex = 0
}
public enum UIImpactFeedbackStyle { case light, medium, heavy }
open class UIImpactFeedbackGenerator: NSObject {
    public typealias FeedbackStyle = UIImpactFeedbackStyle
    public init(style: UIImpactFeedbackStyle) {}
    open func impactOccurred(intensity: CGFloat) {}
    open func prepare() {}
}
open class UIDevice: NSObject { public static let current = UIDevice(); open func playInputClick() {} }
public protocol UIInputViewAudioFeedback { var enableInputClicksWhenVisible: Bool { get } }
public enum UIReturnKeyType { case `default`, go, google, join, next, route, search, send, yahoo, done, emergencyCall, `continue` }
public enum UIKeyboardType { case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad }
public enum UIKeyboardAppearance { case `default`, dark, light }
public protocol UITextInput: AnyObject {}
public protocol UITextDocumentProxy: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var selectedText: String? { get }
    var documentIdentifier: UUID { get }
    var hasText: Bool { get }
    var returnKeyType: UIReturnKeyType? { get }
    var keyboardType: UIKeyboardType? { get }
    var keyboardAppearance: UIKeyboardAppearance? { get }
    var enablesReturnKeyAutomatically: Bool? { get }
    func insertText(_ text: String)
    func deleteBackward()
    func adjustTextPosition(byCharacterOffset offset: Int)
    func setMarkedText(_ markedText: String, selectedRange: NSRange)
    func unmarkText()
}
public protocol UIViewControllerTransitionCoordinatorContext {}
public protocol UIViewControllerTransitionCoordinator {
    func animate(alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool
}
open class UIViewController: UIResponder {
    open var view: UIView! { UIView() }
    open var traitCollection: UITraitCollection { UITraitCollection() }
    open func viewDidLoad() {}
    open func viewWillAppear(_ animated: Bool) {}
    open func viewDidAppear(_ animated: Bool) {}
    open func viewWillDisappear(_ animated: Bool) {}
    open func viewWillLayoutSubviews() {}
    open func didReceiveMemoryWarning() {}
    open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
    open func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {}
}
open class UIInputViewController: UIViewController {
    open var textDocumentProxy: any UITextDocumentProxy { fatalError() }
    open var needsInputModeSwitchKey: Bool { false }
    open var hasFullAccess: Bool { false }
    open func dismissKeyboard() {}
    open func handleInputModeList(from view: UIView, with event: UIEvent) {}
    open func textWillChange(_ textInput: (any UITextInput)?) {}
    open func textDidChange(_ textInput: (any UITextInput)?) {}
    open func selectionDidChange(_ textInput: (any UITextInput)?) {}
    open func requestSupplementaryLexicon(completion: @escaping (UILexicon) -> Void) {}
}
open class UILexiconEntry: NSObject {
    open var userInput: String { "" }
    open var documentText: String { "" }
}
open class UITextChecker: NSObject {
    public override init() {}
    open func rangeOfMisspelledWord(in string: String, range: NSRange, startingAt startingOffset: Int, wrap wrapFlag: Bool, language: String) -> NSRange { NSRange(location: NSNotFound, length: 0) }
    open func guesses(forWordRange range: NSRange, in string: String, language: String) -> [String]? { nil }
    open func completions(forPartialWordRange range: NSRange, in string: String, language: String) -> [String]? { nil }
}
open class UILexicon: NSObject {
    open var entries: [UILexiconEntry] { [] }
}

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key("NSFont")
}
extension NSString {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]?) -> CGSize { .zero }
}
