import Testing

/// InviteCode（招待コードの形式・生成）のテスト
struct InviteCodeTests {

    // MARK: - 生成

    @Test func 生成コードは規定桁数() {
        for _ in 0..<200 {
            #expect(InviteCode.generate().count == InviteCode.length)
        }
    }

    @Test func 生成コードは生成用文字集合のみ() {
        let allowed = Set(InviteCode.generationCharacters)
        for _ in 0..<200 {
            #expect(InviteCode.generate().allSatisfy { allowed.contains($0) })
        }
    }

    @Test func 生成コードは紛らわしい文字を含まない() {
        let forbidden: Set<Character> = ["O", "0", "I", "1"]
        for _ in 0..<200 {
            #expect(InviteCode.generate().allSatisfy { !forbidden.contains($0) })
        }
    }

    @Test func 生成コードは形式チェックを通る() {
        for _ in 0..<200 {
            #expect(InviteCode.isValidFormat(InviteCode.generate()))
        }
    }

    // MARK: - 形式チェック（有効）

    @Test(arguments: [
        "ABCDEFGH",   // 大文字8桁
        "abcdefgh",   // 小文字も英数字なので形式上は有効
        "AB23CD45",   // 英数字混在
        "12345678",   // 数字のみ
    ])
    func 有効な形式(_ code: String) {
        #expect(InviteCode.isValidFormat(code))
    }

    // MARK: - 形式チェック（無効）

    @Test(arguments: [
        "",            // 空
        "ABCDEFG",     // 7桁（短い）
        "ABCDEFGHI",   // 9桁（長い）
        "ABCDEF-H",    // 記号を含む
        "ABCDEF H",    // 空白を含む
        "ABCDEFG\u{3042}", // 日本語を含む（あ）
    ])
    func 無効な形式(_ code: String) {
        #expect(!InviteCode.isValidFormat(code))
    }

    // MARK: - 入力正規化

    @Test func 正規化は小文字を大文字化() {
        #expect(InviteCode.normalizedInput("abcdefgh") == "ABCDEFGH")
    }

    @Test func 正規化は英数以外を除去() {
        #expect(InviteCode.normalizedInput("ab-cd ef!") == "ABCDEF")
        #expect(InviteCode.normalizedInput("あABいC") == "ABC")
    }

    @Test func 正規化は規定桁数で切り詰め() {
        // 9文字 → 8文字
        #expect(InviteCode.normalizedInput("ABCDEFGHI") == "ABCDEFGH")
        #expect(InviteCode.normalizedInput("ABCDEFGHI").count == InviteCode.length)
    }

    @Test func 正規化は空文字を空のまま返す() {
        #expect(InviteCode.normalizedInput("") == "")
        #expect(InviteCode.normalizedInput("！＃あ") == "")
    }

    @Test func 正規化後は有効な形式() {
        // 余分な記号と長さを含む入力でも、正規化すれば形式チェックを通る
        #expect(InviteCode.isValidFormat(InviteCode.normalizedInput("ab-cd-ef-gh-ij")))
    }
}
