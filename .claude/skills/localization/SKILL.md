---
name: localization
description: String Catalog（Localizable.xcstrings）と String(localized:) を使った文言管理ルール。UI 文言を追加・改修する時、ハードコードされた Text("...") を見つけて置き換える時に使う。
---

# ローカライズ

文言は `heyho_ios/Localizable.xcstrings`（String Catalog）で管理し、コードからは `String(localized:)` / `LocalizedStringKey` で参照する。

> **現状: 移行途中。** `String(localized:)` を使っている箇所と、`Text("MY NAME IS")` のようにハードコードされた英語が混在している。新規・改修時は必ずローカライズ経由にし、見つけたハードコードは順次置き換える。

---

## ルール

1. **UI 文言を `Text("...")` で直書きしない。** String Catalog のキーを通す。
2. `SwiftUI.Text` は `LocalizedStringKey` を受けるので、**`Text("キー")` はそのままローカライズ対象**になる（キーが xcstrings に登録されていれば翻訳が引かれる）。
3. **文字列を変数・ロジックで使う場合は `String(localized:)`** を使う（エラーメッセージ・条件分岐など）。

```swift
// View ラベル: Text はキーをそのまま渡せる（LocalizedStringKey）
Text("ADD FRIENDS")

// 変数・エラー文言: String(localized:) で明示的にローカライズ
errorMessage = String(localized: "Code not found")
let label = inviteCodeCopied ? String(localized: "Copied") : String(localized: "Copy")

// プレースホルダ（TextField の prompt 等）
TextField("", text: $name, prompt: Text("6-16 characters"))
```

---

## 新しい文言を追加する手順

1. コードで `Text("New key")` または `String(localized: "New key")` を書く
2. Xcode で `Localizable.xcstrings` を開く（ビルドすると自動でキーが収集される）
3. 各言語（日本語など）の翻訳を入力する
4. キー自体を英語の自然文にする運用（`MY NAME IS` など UI そのままの表記）

---

## ハードコード撲滅（移行作業）

`Text("...")` の英語直書きが残っている主な箇所:

- `MyPage/MyPageView.swift`（`MY NAME IS` / `ADD FRIENDS` / `PREMIUM` など多数）
- `MyPage/EditProfileView.swift`（`SOLID COLORS` / `GRADIENTS` など）
- `Profile/ProfileView.swift`（`Loading...`）

これらを触る時は、その画面ぶんをまとめて String Catalog 化すると効率的。

### 直書きの探し方

```bash
# ローカライズされていない可能性のある Text を洗い出す
grep -rn 'Text("' heyho_ios/Features heyho_ios/Auth | grep -vi preview
```

---

## 注意

- Preview 内の `Text` は実害が小さいので優先度は低い（ただし新規は揃えるのが望ましい）
- `accessibilityIdentifier` はローカライズ対象に**しない**（UI テスト用の固定 ID）
