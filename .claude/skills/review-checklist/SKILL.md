---
name: review-checklist
description: 実装後のコードレビュー観点（View設計・State・非同期・デザイントークン・Firestore・Preview）と /simplify の制約。実装が一段落した時、PR を出す前のセルフレビュー時に使う。
---

# コードレビュー チェックリスト

実装が一段落したら、または `/simplify` / `/code-review` 実行時にこの観点で確認する。

---

## View 設計

- [ ] `body` が 80 行を超えていたら `@ViewBuilder` メソッドまたは BodyView に切り出す
- [ ] BodyView に `@EnvironmentObject` / `@StateObject` が混入していないか
- [ ] `hasLoadedOnce` フラグで二重ロードを防いでいるか
- [ ] `onAppear` に直接ロジックを書かず `private func` に委譲しているか

## State 設計

- [ ] 派生できる値を `@State` で持っていないか（computed property で十分なことが多い）
- [ ] `storeService.isPremium` などは BodyView に直接渡しているか（`Bool` として）

## 非同期処理

- [ ] Firebase 操作は `async/await`（コールバックを使っていないか）
- [ ] UI 更新は `@MainActor` または `MainActor.run` を通しているか
- [ ] 並列実行できる場合は `withThrowingTaskGroup` / `async let` を使っているか

## デザイントークン

- [ ] 数値リテラルが直書きされていないか（`AppSpacing.*` / `AppTypography.*` / `AppSize.*` を使う）
- [ ] 色の hex 文字列が直書きされていないか（`AppColor.*` を使う）
- [ ] 同じ値が 2 箇所以上あったらトークンまたは定数に一元化したか

## モデル・Firestore

- [ ] 新規ドキュメントの `createdAt` は `FieldValue.serverTimestamp()` を使っているか
- [ ] `updateXxx` 系メソッドは `merge: true` で既存フィールドを保持しているか
- [ ] アイコンカラーの保存・読み込みは `IconColorValue` 経由か

## Cloud Functions・セキュリティ

- [ ] 新しいコレクション操作は `firestore.rules` に反映したか
- [ ] FCM 送信はエラーハンドリング（`try/catch` + `console.error`）しているか
- [ ] `npm run build` が通るか確認したか

## Preview・テスト

- [ ] BodyView は `EnvironmentObject` なしに `#Preview` で表示できるか
- [ ] ローディング・空・データあり の最低 3 ケースを Preview でカバーしているか

---

## `/simplify` でのセルフレビュー制約

- 既存 UI の見た目は変えない
- 既存の画面遷移は変えない
- まずレビュー結果だけを出す（修正はユーザーの承認後）
- 修正案は小さな単位に分けて提示する
