import Foundation

/// 招待コードの形式定義・バリデーション・生成（Firebase 非依存の純粋ロジック）
enum InviteCode {
    /// 招待コードの桁数（生成・入力バリデーション共通）
    static let length = 8

    /// 生成に使う文字集合（紛らわしい文字 O/0/I/1 を除外）
    static let generationCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    /// 招待コードに使える文字かどうか（ASCII英数字のみ）
    static func isCodeCharacter(_ char: Character) -> Bool {
        char.isASCII && (char.isLetter || char.isNumber)
    }

    /// 形式チェック: ASCII英数字のみ・規定桁数
    static func isValidFormat(_ code: String) -> Bool {
        code.count == length && code.allSatisfy(isCodeCharacter)
    }

    /// 英数字8桁の招待コードを生成する
    static func generate() -> String {
        String((0..<length).compactMap { _ in generationCharacters.randomElement() })
    }
}
