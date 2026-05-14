# SKILLS.md — HeyHo iOS 開発チートシート

Claude Code がこのプロジェクトで作業する際の定型パターン集。
新機能追加・レビュー・デプロイ時に参照すること。

---

## 1. 新しい SwiftUI View を追加するパターン

### ファイル配置

```
heyho_ios/Features/<FeatureName>/
  <FeatureName>View.swift        ← データロード担当（EnvironmentObject 注入）
  <FeatureName>BodyView.swift    ← 純粋 UI（プレビュー可能）
  （小さければ 1 ファイルに MARK: で分けてもよい）
```

### View 分割の鉄則

- **データ取得 View**（`FriendsView` パターン）
  - `@EnvironmentObject var authState: AuthState`
  - `@EnvironmentObject var storeService: StoreService`
  - `@State` でデータを保持し、`onAppear` で `Task { await load() }` を呼ぶ
  - 再ロードが必要な場合は `hasLoadedOnce` フラグで二重ロードを防ぐ
  - UI は **BodyView に全部渡す**（Binding + クロージャ経由）

- **純粋 UI BodyView**（`FriendsBodyView` パターン）
  - `@EnvironmentObject` 不使用・`let` と `@Binding` のみ
  - Preview マクロで複数ケースをカバー（ローディング・空・データあり）

### デザイントークン（ハードコード禁止）

| 用途 | トークン |
|------|---------|
| 色 | `AppColor.backgroundPrimary` / `.textPrimary` など |
| 余白 | `AppSpacing.spSmall(8)` / `.spMedium(12)` / `.spLarge(16)` / `.spXlarge(24)` |
| フォントサイズ | `AppTypography.caption(12)` / `.label(14)` / `.body(16)` / `.heading(24)` / `.display(32)` |
| サイズ | `AppSize.iconDefault(48)` / `.buttonHeight(56)` / `.borderStrong(4)` |

```swift
// 良い例
.font(.system(size: AppTypography.heading, weight: .black))
.padding(.horizontal, AppSpacing.spXlarge)

// NG（ハードコード）
.font(.system(size: 24, weight: .black))
.padding(.horizontal, 24)
```

### 非同期処理のルール

```swift
// View 内: Task でラップ、エラーは @State private var errorMessage: String? に
private func loadData() async {
    do {
        items = try await FirestoreService.shared.someMethod()
    } catch {
        errorMessage = error.localizedDescription
    }
}

// UI スレッドへの反映は MainActor.run
await MainActor.run { self.items = result }
```

### Preview の書き方

```swift
#if DEBUG
#Preview("BodyView - データあり") {
    SomeBodyView(
        items: previewItems,
        isLoading: false,
        onAction: { _ in }
    )
}
#Preview("BodyView - ローディング") { ... }
#Preview("BodyView - 空") { ... }
#endif
```

### 再描画を増やさないために

- `FriendsView` → `FriendsBodyView` のようにデータView と UIView を分離する
- BodyView は `let` を使い、必要な Binding のみ受け取る
- `storeService.isPremium` など頻繁に変わらない値は親で取得して `Bool` として渡す

---

## 2. Cloud Functions を追加するパターン

### ファイル

```
functions/src/index.ts   ← すべての関数をここに書く
functions/src/notificationTemplates.ts  ← 通知テンプレートなど補助ファイル
```

### Firestore トリガーのテンプレート

```typescript
export const onXxxCreated = functions.firestore
  .document("collection/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    // 処理
  });
```

### デプロイ手順

```bash
cd functions
npm run build      # TypeScript コンパイル
npm run deploy     # Firebase にデプロイ
```

### 注意事項

- `createdAt` は `FieldValue.serverTimestamp()` を使うため、トリガー直後は `null` になる可能性がある
- FCM トークンは `users/{uid}/private/data` のサブドキュメントに格納
- バッチ削除は 500件上限に注意（`batchDelete` ヘルパーを再利用する）
- 新しいコレクションを操作する場合は `firestore.rules` も更新する

---

## 3. レビュー・リファクタ チェックリスト

### View の複雑度チェック

- [ ] `body` が 80行を超えていたら分割を検討する
- [ ] `if / else` のネストが 3段以上あったら `@ViewBuilder` メソッドに切り出す
- [ ] `onAppear` に直接ロジックを書かず、`private func` に委譲しているか
- [ ] `hasLoadedOnce` などのフラグで二重ロードを防いでいるか

### State 設計チェック

- [ ] `@EnvironmentObject` は AuthState / StoreService のみ（それ以外は Binding か let で渡す）
- [ ] BodyView に `@State` や `@EnvironmentObject` が混入していないか
- [ ] 派生できる値を `@State` で持っていないか（computed property で十分なことが多い）

### 非同期処理チェック

- [ ] Firebase 操作は `async/await` か（コールバックを使っていないか）
- [ ] UI 更新は `@MainActor` または `MainActor.run` を通しているか
- [ ] Task が並列実行できるなら `withTaskGroup` / `async let` を使っているか

### デザイントークン チェック

- [ ] 数値リテラル（`16`, `24`, `32`）が直書きされていないか
- [ ] 色の hex 文字列が直書きされていないか（`AppColor.*` を使う）
- [ ] 同じ値が 2箇所以上にある場合、トークン or 定数に一元化したか

### Preview / テスト チェック

- [ ] BodyView は `#Preview` で `EnvironmentObject` なしに表示できるか
- [ ] ローディング・空・エラー・正常の 4ケースを Preview でカバーしているか
- [ ] UI Test で確認したいボタン・ラベルに `.accessibilityIdentifier` が付いているか

### Cloud Functions チェック

- [ ] 新しいコレクション操作は `firestore.rules` に反映したか
- [ ] FCM 送信はエラーハンドリング（`try/catch` + `console.error`）しているか
- [ ] `npm run build` が通るか（デプロイ前に必ず確認）

---

## 4. `/simplify` — 実装後セルフコードレビュー方針

実装が一段落したら `/simplify` を使って SwiftUI View の品質をセルフレビューする。

### 目的

- `body` が複雑になっていないか確認する
- View の分割候補を提案する
- 状態管理が View に寄りすぎていないか確認する

### 確認観点

| 観点 | 確認内容 |
|------|---------|
| View 分割 | `body` が肥大化していないか、`@ViewBuilder` メソッドへの切り出し候補はないか |
| 状態管理 | `@State` / `@Binding` / `@ObservableObject` の責務が適切か、BodyView に `@EnvironmentObject` が混入していないか |
| 非同期処理 | `async/await` を正しく使えているか、`@MainActor` の漏れはないか |
| 再描画 | 不要な `@Published` 更新や親 View の再描画を誘発する構造になっていないか |
| Preview | `EnvironmentObject` なしに BodyView を Preview できるか、主要なケース（空・ローディング・エラー・正常）が揃っているか |
| UI Test | 主要な操作要素に `.accessibilityIdentifier` が付いているか |

### 制約（必ず守る）

- 既存 UI の見た目は変えない
- 既存の画面遷移は変えない
- まずレビュー結果だけを出す（修正はユーザーの承認後）
- 修正案は小さな単位に分けて提示する

### アシスタントへの指示テンプレート

```
以下の観点で View をレビューし、改善案を日本語でまとめてください。

確認観点:
1. View の分割候補（body が長い、入れ子が深いなど）
2. State / Binding / ObservableObject の責務が適切か
3. 非同期処理の扱い（MainActor 漏れ・エラーハンドリング等）
4. 再描画が増えそうな箇所
5. Preview しやすい構造か
6. UI Test で確認しやすい構造か

制約:
- 既存 UI の見た目・画面遷移は変えない
- まずレビュー結果のみ提示する
- 修正案は小さな単位で提案する
```
