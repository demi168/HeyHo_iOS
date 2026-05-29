---
name: design-tokens
description: AppColor / AppSpacing / AppTypography / AppSize デザイントークンの一覧と使い方。UI を作る・色/余白/サイズ/フォントを指定する時に使う。数値リテラルや hex のハードコードは禁止。
---

# デザイントークン

> 数値リテラルや hex 文字列を直書きしない。`AppColor.*` / `AppSpacing.*` / `AppTypography.*` / `AppSize.*` を使う。
> 同じ値が 2 箇所以上に出たらトークンまたは定数に一元化する。「1箇所変えれば全部変わる」を目指す。

定義場所: `heyho_ios/DesignTokens/`

---

## AppSpacing（余白）

| 定数 | 値 |
|------|----|
| `AppSpacing.spXsmall` | 4 |
| `AppSpacing.spSmall` | 8 |
| `AppSpacing.spMedium` | 12 |
| `AppSpacing.spLarge` | 16 |
| `AppSpacing.spXlarge` | 24 |
| `AppSpacing.spXxlarge` | 32 |

## AppTypography（フォントサイズ）

| 定数 | 値 |
|------|----|
| `AppTypography.caption` | 12 |
| `AppTypography.label` | 14 |
| `AppTypography.body` | 16 |
| `AppTypography.heading` | 24 |
| `AppTypography.title` | 28 |
| `AppTypography.display` | 32 |

## AppSize（サイズ）

| 定数 | 値 |
|------|-----|
| `AppSize.borderDefault` | 1 |
| `AppSize.borderUnderline` | 2 |
| `AppSize.borderStrong` | 4 |
| `AppSize.buttonIcon` | 40 |
| `AppSize.buttonHeight` | 56 |
| `AppSize.iconDefault` | 48 |
| `AppSize.iconLarge` | 96 |
| `AppSize.capsuleButtonWidth` | 80 |

## AppColor（色）

代表的なセマンティックカラー:

```swift
AppColor.backgroundPrimary    // #34C759（メイン緑）
AppColor.backgroundSecondary  // #FFFFFF
AppColor.textPrimary          // #000000
AppColor.textSecondary        // #9CA3AF
AppColor.textInverse          // #FFFFFF
AppColor.textDestructive      // #FF383C
AppColor.borderDefault        // #E5E7EB
AppColor.borderStrong         // #000000
AppColor.messageHey           // #0088FF
AppColor.messageHo            // #FF8D28
AppColor.messageLetsGo        // #34C759
AppColor.interactiveDestructive // #FF383C
```

グラデーション・アイコンカラーのプリセットも `AppColor` に集約:

```swift
AppColor.premiumGradientPresets  // [GradientPreset]
AppColor.freeIconPresets         // [(name: String, hex: String)]
AppColor.premiumIconPresets      // [(name: String, hex: String)]
```

---

## 使い方

```swift
// 良い例
.font(.system(size: AppTypography.heading, weight: .black))
.padding(.horizontal, AppSpacing.spXlarge)
.foregroundColor(AppColor.textPrimary)
.frame(height: AppSize.buttonHeight)

// NG（ハードコード）
.font(.system(size: 24, weight: .black))
.padding(.horizontal, 24)
```
