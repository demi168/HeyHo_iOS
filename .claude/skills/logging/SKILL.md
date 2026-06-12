---
name: logging
description: AppLogger（os.Logger のカテゴリ別ラッパー）の使い方・try? 握りつぶし禁止ルール・privacy 指定の方針。ログを追加する時、エラーハンドリングを書く時に使う。
---

# ログ

ログは `App/AppLogger.swift` の **`AppLogger`**（`os.Logger` のカテゴリ別ラッパー）を使う。
`print()` は使わない。

---

## カテゴリ

| アクセサ | category | 使う場所 |
|---------|----------|---------|
| `AppLogger.firestore` | firestore | Firestore 操作の失敗・デコードフォールバック |
| `AppLogger.push` | push | FCM トークン取得/保存 |
| `AppLogger.store` | store | StoreKit 課金・プレミアム同期 |
| `AppLogger.auth` | auth | 認証・ユーザー情報の取得/再取得 |
| `AppLogger.feedback` | feedback | サウンド/ハプティクス |

```swift
AppLogger.firestore.error("getUser failed (userId: \(uid)): \(error.localizedDescription)")
AppLogger.feedback.info("サウンドファイル未配置: \(name)")
```

レベルは `.error`（失敗）/ `.info`（想定内の情報）を基本に使い分ける。

---

## `try?` で握りつぶさない（必須ルール）

エラーを `try?` で黙って捨てない。失敗は必ず **ログ** か **`.errorAlert`** のどちらかに接続する。

| 状況 | つなぎ先 |
|------|---------|
| ユーザーに伝えるべき失敗（保存失敗など） | `errorMessage = error.localizedDescription` → `.errorAlert($errorMessage)` |
| UI は空/キャッシュ表示のままでよい失敗（読込失敗など） | `AppLogger.<category>.error(...)` |
| 意図的なフォールバック（デコード失敗→デフォルト等） | フォールバックしつつ `AppLogger.<category>.error(...)` でログだけ残す |

```swift
// NG
let user = try? await FirestoreService.shared.getUser(userId: uid)

// OK（読込失敗はログ、表示は空のまま）
do {
    guard let user = try await FirestoreService.shared.getUser(userId: uid) else { return }
    await MainActor.run { currentUser = user }
} catch {
    AppLogger.firestore.error("ユーザー読込に失敗: \(error.localizedDescription)")
}
```

---

## privacy 指定

`os.Logger` は文字列補間値をデフォルトで `private` 扱いにする（リリースビルドで `<private>` にマスク）。
そのため userId・トークン等を埋め込んでも明示的な privacy 指定は不要。
**公開してよい固定文字列以外に `.public` を付けない。**

ログを流して確認する時:
```bash
xcrun simctl spawn <udid> log stream --level debug --style compact \
  --predicate 'subsystem == "com.demiflare168.HeyHo"'
```
