import Testing

/// テストターゲットの疎通確認を兼ねたスモークテスト。
/// テスト対象はアプリターゲットと dual membership でコンパイルされる純粋ロジックのみ
/// （Foundation 以外を import するファイルはテスト対象に追加しない）
struct SmokeTests {
    @Test func 生成した招待コードは形式チェックを通る() {
        for _ in 0..<100 {
            #expect(InviteCode.isValidFormat(InviteCode.generate()))
        }
    }
}
