---
name: testing
description: HeyHoTests のターゲット構成（ホストなし・dual membership）・Swift Testing の書き方・xcodebuild test コマンド・新ロジックは Models/ に純粋関数で切り出してテストする規約。テストを追加/実行する時、テスト可能なロジックを設計する時に使う。
---

# テスト

ユニットテストは **Swift Testing**（`import Testing` / `@Test` / `#expect`）で書く。XCTest は使わない。

---

## ターゲット構成（重要）

`HeyHoTests` は **アプリをホストしない独立ターゲット**。`@testable import HeyHo` は使わず、
**テスト対象ファイルをアプリと dual membership でコンパイル**して検証する。

- テストファイル（`HeyHoTests/*.swift`）はテストターゲット単独メンバー。
- テスト対象のロジック（`Models/` の純粋型）は **アプリターゲット + テストターゲットの両方**に所属させる（pbxproj で dual membership）。
- このため **テスト対象にできるのは `Foundation` のみ import の純粋ロジックに限る**。SwiftUI / Firebase を import するファイルはテスト対象に追加しない（リンクエラーになる）。

### 現在のテスト対象（`Models/`）

| ファイル | import | テスト |
|---------|--------|--------|
| `InviteCode.swift` | Foundation | `InviteCodeTests` |
| `DisplayNameValidator.swift` | Foundation | `DisplayNameValidatorTests` |
| `MessageType.swift` | Foundation | `MessageTypeTests` |
| `IconColorValue.swift` | Foundation | `IconColorValueTests` |

`PremiumConfig` / `GradientPreset` も dual membership 済み（テスト対象の依存のため）。

---

## 新しいロジックを追加する時の規約

**テストしたい判定・変換ロジックは、View や Service に直接書かず `Models/` に純粋関数（または enum）として切り出す。**

- 例: 名前バリデーションは `DisplayNameValidator.validate()`（エラー種別を enum で返す）、文言変換は View 側。
- 切り出したら pbxproj で **アプリ + テストの dual membership** に登録し、`HeyHoTests/` に対応するテストを追加する。
- pbxproj は手書き8桁ID規約（`F`/`B` + 8桁）。テストファイルは `F0020xxx`/`B0020xxx`、dual membership の build file は `B0020010`〜系を踏襲。

---

## 書き方（Swift Testing）

```swift
import Testing

/// 〇〇のテスト
struct XxxTests {
    @Test func 日本語で意図を書く() {
        #expect(Xxx.method(input) == expected)
    }

    // ランダム性のあるものは反復で検証
    @Test func 生成コードは規定桁数() {
        for _ in 0..<200 {
            #expect(InviteCode.generate().count == InviteCode.length)
        }
    }
}
```

- テスト名は日本語の関数名で「何を保証するか」を表す。
- 順序が意味を持つ判定（例: `DisplayNameValidator` の不正文字 > 予約語 > 長さ）は、その順序自体をテストで固定する。

---

## 実行

```bash
xcodebuild test -project heyho_ios.xcodeproj -scheme HeyHo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:HeyHoTests
```

成功時は `** TEST SUCCEEDED **` と `Test run with N tests in M suites passed`。
**ビルド/テストが通らない状態でコミットしない。**

UI を伴う挙動の検証は自動タップではなく **手動操作＋ログ/スクショ方式**で行う（ユーザーがシミュレータを操作し、Fable が `log stream` と `simctl screenshot` で確認。詳細はメモリ `feedback-verification-workflow`）。
