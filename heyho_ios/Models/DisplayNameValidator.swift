import Foundation

/// 表示名のバリデーション（Firebase・UI 非依存の純粋ロジック）。
/// エラー文言への変換は View 側（EditProfileView）で行う
enum DisplayNameValidator {
    /// 表示名の文字数制限（grapheme 単位）。
    /// 変更時は Localizable.xcstrings の文言（"6-16 characters" 等）と firestore.rules の isValidDisplayName も合わせること
    static let lengthRange = 6...16

    enum ValidationError: Equatable {
        case empty
        case disallowedCharacter
        case containsReservedWord
        case tooShort
        case tooLong
    }

    /// バリデーション結果を返す（nil = 有効）
    static func validate(_ input: String) -> ValidationError? {
        let name = input.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return .empty }
        if !name.allSatisfy({ isAllowedCharacter($0) }) { return .disallowedCharacter }
        if name.range(of: "heyho", options: .caseInsensitive) != nil { return .containsReservedWord }
        if name.count < lengthRange.lowerBound { return .tooShort }
        if name.count > lengthRange.upperBound { return .tooLong }
        return nil
    }

    /// 許可文字チェック: ASCII英数字または絵文字のみ
    static func isAllowedCharacter(_ char: Character) -> Bool {
        if char.isASCII { return char.isLetter || char.isNumber }
        // 非ASCII: 絵文字を含む文字のみ許可（日本語等は除外）
        return char.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0xFF)
        }
    }
}
