import Testing

/// DisplayNameValidator（表示名バリデーション）のテスト
struct DisplayNameValidatorTests {

    // MARK: - 有効

    @Test(arguments: [
        "abcdef",            // 下限ちょうど 6
        "abcdefghijklmnop",  // 上限ちょうど 16
        "User23",            // 英数字混在
        "AB23CD",            // 大文字＋数字
    ])
    func 有効な表示名(_ name: String) {
        #expect(DisplayNameValidator.validate(name) == nil)
    }

    @Test func 絵文字は許可される() {
        #expect(DisplayNameValidator.validate("hello\u{1F600}") == nil) // hello😀
    }

    @Test func 前後の空白はトリムされる() {
        #expect(DisplayNameValidator.validate("  abcdef  ") == nil)
    }

    // MARK: - 無効（種別ごと）

    @Test func 空文字はempty() {
        #expect(DisplayNameValidator.validate("") == .empty)
    }

    @Test func 空白のみはempty() {
        #expect(DisplayNameValidator.validate("     ") == .empty)
    }

    @Test(arguments: [
        "\u{3042}\u{3044}\u{3046}\u{3048}\u{304A}\u{304B}", // あいうえおか（日本語6文字）
        "user-name",  // ハイフン
        "user name",  // 内部空白
        "user@mail",  // 記号
    ])
    func 不正文字はdisallowedCharacter(_ name: String) {
        #expect(DisplayNameValidator.validate(name) == .disallowedCharacter)
    }

    @Test(arguments: ["heyho", "HEYHO", "myHeyHoName", "xxheyhoxx",
                      "heyboy", "HEYBOY", "myHeyBoyName", "xxheyboyxx"])
    func 予約語はcontainsReservedWord(_ name: String) {
        #expect(DisplayNameValidator.validate(name) == .containsReservedWord)
    }

    @Test(arguments: ["a", "abc", "abcde"]) // 1〜5文字
    func 短すぎる名前はtooShort(_ name: String) {
        #expect(DisplayNameValidator.validate(name) == .tooShort)
    }

    @Test func 上限超過はtooLong() {
        #expect(DisplayNameValidator.validate("abcdefghijklmnopq") == .tooLong) // 17文字
    }

    // MARK: - チェック順序の保証

    @Test func 不正文字は長さより優先して判定される() {
        // 5文字だが不正文字を含む → tooShort ではなく disallowedCharacter
        #expect(DisplayNameValidator.validate("ab@d") == .disallowedCharacter)
    }

    @Test func 予約語は長さより優先して判定される() {
        // "heyho" は5文字（下限未満）だが tooShort ではなく予約語判定
        #expect(DisplayNameValidator.validate("heyho") == .containsReservedWord)
    }
}
