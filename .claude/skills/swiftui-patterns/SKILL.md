---
name: swiftui-patterns
description: SwiftUI の View 構成（DataView/BodyView 分離）・EnvironmentObject（AuthState/StoreService）・エラー処理（.errorAlert）・ナビゲーション（fullScreenCover/sheet）の定型。View を新規追加・改修する時に使う。
---

# SwiftUI パターン

View 構成・EnvironmentObject・エラー処理・ナビゲーションの定型。
デザイントークンは [design-tokens](../design-tokens/SKILL.md) を参照。

---

## 1. View の構成（DataView / BodyView 分離）

### ファイル構成

```
heyho_ios/Features/<FeatureName>/
  <FeatureName>View.swift      ← データロード担当
  （小さければ 1ファイルに MARK: で分けてよい）
```

### DataView（FriendsView パターン）

```swift
struct XxxView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService  // プレミアム判定が必要な場合のみ
    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var errorMessage: String?

    var body: some View {
        XxxBodyView(
            items: items,
            isLoading: isLoading,
            isPremium: storeService.isPremium,
            onAction: doSomething
        )
        .onAppear {
            guard !hasLoadedOnce else { return }  // 二重ロード防止
            Task { await loadData() }
        }
        .errorAlert($errorMessage)
    }

    private func loadData() async {
        guard let uid = authState.currentUserId else { return }
        if !hasLoadedOnce { isLoading = true }
        defer { isLoading = false; hasLoadedOnce = true }
        do {
            items = try await FirestoreService.shared.someMethod(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### BodyView（純粋 UI・プレビュー可能）

```swift
struct XxxBodyView: View {
    // EnvironmentObject 禁止。let と @Binding のみ。
    let items: [Item]
    let isLoading: Bool
    let isPremium: Bool
    let onAction: (Item) -> Void
}
```

**BodyView の原則:**
- `@EnvironmentObject` / `@StateObject` を持たない
- `let` で値を受け取り、変更が必要な場合のみ `@Binding`
- アクション（非同期含む）はクロージャ経由で受け取る（例: `onSend: (AppUser) -> Void`）
- `storeService.isPremium` など Bool 値は親で取得して渡す

### Preview の書き方

```swift
#if DEBUG
#Preview("BodyView - リスト") {
    XxxBodyView(items: previewItems, isLoading: false, isPremium: true, onAction: { _ in })
}
#Preview("BodyView - ローディング") {
    XxxBodyView(items: [], isLoading: true, isPremium: false, onAction: { _ in })
}
#Preview("BodyView - 空") {
    XxxBodyView(items: [], isLoading: false, isPremium: false, onAction: { _ in })
}
#endif
```

---

## 2. EnvironmentObject

アプリ全体で inject されている EnvironmentObject は 2 つのみ:

| クラス | 役割 |
|--------|------|
| `AuthState` | 認証状態・currentUser・currentUserId |
| `StoreService` | isPremium・課金処理 |

```swift
@EnvironmentObject var authState: AuthState
@EnvironmentObject var storeService: StoreService

guard let uid = authState.currentUserId else { return }
if storeService.isPremium { ... }
```

`FirestoreService` と `PushService` は `@EnvironmentObject` ではなく `.shared` シングルトンでアクセスする。

---

## 3. エラーハンドリング

カスタム `.errorAlert` View Modifier を使う:

```swift
@State private var errorMessage: String?

var body: some View {
    SomeView()
        .errorAlert($errorMessage)  // errorMessage が非nil になるとアラート表示
}

// エラー発生時
errorMessage = error.localizedDescription
```

---

## 4. ナビゲーション

```swift
// モーダル（全画面）
.fullScreenCover(isPresented: $showMyPage, onDismiss: {
    Task { await authState.refreshCurrentUser() }
}) {
    MyPageView().environmentObject(authState)
}

// シート（ハーフモーダル）
.sheet(isPresented: $showPaywall) {
    PaywallView().environmentObject(storeService)
}
```

`environmentObject` の注入を忘れないこと。`.fullScreenCover` / `.sheet` は新しい View ツリーになるため、親の EnvironmentObject が引き継がれない。
