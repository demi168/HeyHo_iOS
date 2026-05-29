---
name: firebase
description: Firestore 操作（async/await・並列取得・private サブドキュメント）・データモデル（@DocumentID・serverTimestamp）・IconColorValue・プレミアムゲート・Cloud Functions の定型。データの取得/保存、課金、関数を触る時に使う。
---

# Firebase・データ層

Firestore 操作・データモデル・アイコンカラー・プレミアムゲート・Cloud Functions の定型。

---

## 1. Firestore 操作

### 基本（async/await）

```swift
// 取得
let user = try await FirestoreService.shared.getUser(userId: uid)

// 更新（merge: true で既存フィールドを保持）
try await db.collection("users").document(userId).setData(["field": value], merge: true)

// createdAt は必ず serverTimestamp
"createdAt": FieldValue.serverTimestamp()
```

### 並列取得（withThrowingTaskGroup）

```swift
let users = try await withThrowingTaskGroup(of: AppUser?.self) { group in
    for uid in userIds {
        group.addTask { try await FirestoreService.shared.getUser(userId: uid) }
    }
    var result: [AppUser] = []
    for try await user in group {
        if let user { result.append(user) }
    }
    return result
}
```

### UI スレッドへの反映

```swift
await MainActor.run { self.items = result }
```

### private サブドキュメント

FCM トークン・プレミアムステータス・招待コードは `users/{uid}/private/data` に保存:

```swift
try await FirestoreService.shared.updateFCMToken(userId: uid, token: token)
try await FirestoreService.shared.updatePremiumStatus(userId: uid, isPremium: true)
```

---

## 2. データモデル

```swift
struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?   // Firestore ドキュメントIDは @DocumentID
    var displayName: String
    var createdAt: Date            // serverTimestamp → 直後は nil になりうる
    var iconColor: String?         // 例: "FF6B6B" / "gradient:sunset"

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "displayName"
        case createdAt = "createdAt"
        case iconColor = "iconColor"
    }
}
```

**ルール:**
- Firestore ドキュメント ID は `@DocumentID var id: String?`（`id` は Firestore が inject）
- `serverTimestamp()` で書いたフィールドは直後に読むと `nil` になる場合がある
- `createdAt` は `createUser` 時の 1 回だけセット。`updateDisplayName` では上書きしない

---

## 3. アイコンカラー（IconColorValue）

`AppUser.iconColor` は文字列で Firestore に保存。`IconColorValue` 型で扱う:

| 種類 | Firestore 文字列 | Swift |
|------|----------------|-------|
| ソリッド | `"FF6B6B"` | `.solid(hex: "FF6B6B")` |
| グラデーションプリセット | `"gradient:sunset"` | `.gradient(presetId: "sunset")` |
| カスタムグラデーション | `"gradient_custom:FF6B6B,34C759"` | `.customGradient(hexStops: [...])` |

```swift
// Firestore文字列 → IconColorValue
let colorValue = IconColorValue(firestoreString: user.iconColor)

// IconColorValue → Firestore文字列（保存時）
let str = colorValue.firestoreString
try await FirestoreService.shared.updateIconColor(userId: uid, colorHex: str)
```

プリセット一覧は [design-tokens](../design-tokens/SKILL.md) の `AppColor` を参照。

---

## 4. プレミアムゲート

```swift
// ゲートの判定
if state == .sendLetsGo && !storeService.isPremium {
    showPaywall = true
    return
}

// Paywall の表示
.sheet(isPresented: $showPaywall) {
    PaywallView().environmentObject(storeService)
}
```

`PremiumConfig.productId` が課金商品 ID。新しい有料機能を追加する際はこのパターンに従う。

---

## 5. Cloud Functions

**ファイル:** `functions/src/index.ts`

### Firestore トリガーテンプレート

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
npm run build   # TypeScript コンパイル（必ずデプロイ前に確認）
npm run deploy
```

**注意事項:**
- `createdAt` は `serverTimestamp()` なのでトリガー直後に `null` になる場合がある
- FCM トークンは `users/{uid}/private/data` の `fcmToken` フィールド
- 新しいコレクションを操作したら `firestore.rules` も更新する
- バッチ削除は 500 件上限に注意
