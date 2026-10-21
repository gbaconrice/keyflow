#if canImport(UIKit)
import UIKit

/// キーボードの配色。ライト・ダークで自動的に切り替わる動的カラーを使う。
public enum KeyboardTheme {
    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    private static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }

    /// キーボード全体の背景
    public static let background = dynamic(light: rgb(209, 212, 218), dark: rgb(30, 30, 32))
    /// 文字キー
    public static let key = dynamic(light: rgb(255, 255, 255), dark: rgb(92, 92, 96))
    /// 文字キー（押下中）
    public static let keyPressed = dynamic(light: rgb(184, 189, 199), dark: rgb(62, 62, 66))
    /// 機能キー
    public static let functionalKey = dynamic(light: rgb(171, 177, 189), dark: rgb(58, 58, 62))
    /// 機能キー（押下中）
    public static let functionalKeyPressed = dynamic(light: rgb(255, 255, 255), dark: rgb(92, 92, 96))
    /// 強調キー（確定・検索など）
    public static let accentKey = dynamic(light: rgb(0, 122, 255), dark: rgb(10, 132, 255))
    public static let accentKeyPressed = dynamic(light: rgb(0, 92, 200), dark: rgb(0, 100, 210))
    public static let accentLabel = UIColor.white
    /// キーの文字
    public static let label = dynamic(light: rgb(0, 0, 0), dark: rgb(255, 255, 255))
    /// 補助的な文字（フリック先のヒントなど）
    public static let secondaryLabel = dynamic(light: rgb(110, 112, 118), dark: rgb(170, 170, 176))
    /// 無効なキーの文字
    public static let disabledLabel = dynamic(light: rgb(150, 152, 158), dark: rgb(120, 120, 126))
    /// キーの影
    public static let keyShadow = dynamic(light: rgb(0, 0, 0, 0.30), dark: rgb(0, 0, 0, 0.55))
    /// フリック先を示す吹き出し
    public static let popup = dynamic(light: rgb(255, 255, 255), dark: rgb(110, 110, 116))
    public static let popupActive = dynamic(light: rgb(0, 122, 255), dark: rgb(10, 132, 255))
    /// 候補バー
    public static let candidateBar = dynamic(light: rgb(209, 212, 218), dark: rgb(30, 30, 32))
    public static let candidateSelected = dynamic(light: rgb(255, 255, 255), dark: rgb(92, 92, 96))
    public static let separator = dynamic(light: rgb(160, 164, 172), dark: rgb(70, 70, 74))
}
#endif
