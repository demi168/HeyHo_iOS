---
name: security-rules
description: firestore.rules の構造・SEC-xxx 採番規約・検証関数（isOwner/isPremiumUser/isValid*）・コレクション別ルール・デプロイ前チェック。Firestore のコレクションやフィールドを追加/変更する時、セキュリティルールを書く時に使う。
---

# Firestore セキュリティルール

`firestore.rules` の構造と規約。**新しいコレクション・フィールドを触る時は必ずここを読んでルールも更新する。**

---

## 大原則

1. **`get` は許可、`list`（コレクション列挙）は拒否** — ユーザー一覧や招待コード一覧を引けないようにする。個別取得は `getUsers` のように `get` を並列実行する（[firebase](../firebase/SKILL.md) 参照）。
2. **クライアントの値を信用しない** — `isPremium` のような特権フラグは `users/{uid}/private/data` に置き、ルール内の `get()` で検証する。
3. **書き込みフィールドを `hasOnly` で制限** — 想定外フィールドの混入を防ぐ。
4. **機密情報は private サブドキュメントに隔離** — `fcmToken` / `inviteCode` / `isPremium` は本人のみ read/write。

---

## SEC-xxx 採番規約

セキュリティ関連のルール変更には、対応する GitHub issue 番号を `SEC-xxx` 形式でコメントに残す。

```javascript
// SEC-025: letsGo はプレミアムユーザーのみ送信可能
// SEC-032: 書き込みフィールドを制限し、displayName の型・長さを検証
// SEC-002: getのみ許可、list（コレクション列挙）を拒否
```

新しいセキュリティ制約を入れる時は issue 化し、その番号を `SEC-xxx` としてルールに記載する（issue 化はユーザーに確認 — CLAUDE.md の方針）。

---

## ヘルパー関数

ルール冒頭に共通関数を定義し、各 `match` から呼ぶ:

```javascript
function isSignedIn() { return request.auth != null; }
function isOwner(uid) { return request.auth != null && request.auth.uid == uid; }

// private/data の特権フラグを検証（クライアント値を信用しない）
function isPremiumUser(userId) {
  return get(/databases/$(database)/documents/users/$(userId)/private/data)
           .data.get("isPremium", false) == true;
}

// 入力バリデーション
function isValidDisplayName(name) {
  return name is string && name.size() >= 6 && name.size() <= 32;
}
function isValidIconColor(color) {
  return color is string && color.size() <= 200;
}
```

---

## コレクション別ルールの要点

| コレクション | ルール |
|------------|--------|
| `users/{userId}` | `get` のみ（`list` 拒否）。create/update は本人かつ `hasOnly(["displayName","createdAt","iconColor"])`。変更されたフィールドのみバリデーション |
| `users/.../private/{docId}` | 本人のみ read/write（fcmToken / inviteCode / isPremium） |
| `users/.../friends/{friendId}` | read は双方向（`isOwner(userId) \|\| isOwner(friendId)`）、create/delete は自分側のみ、相手側は Cloud Function が作成、update 禁止 |
| `heyhos/{heyhoId}` | 送信者が本人 + 受信者が友だち（`exists()` 検証）+ messageType は `["hey","ho","letsGo"]` のみ + letsGo は `isPremiumUser` のみ。read は送受信者のみ。update/delete 禁止 |
| `inviteCodes/{code}` | `get` のみ（`list` 拒否）。create は所有者のみ。update/delete 禁止 |

### バリデーションのコツ（update 時）

未変更フィールドにバリデーションを誤適用しないよう、`diff().affectedKeys()` で**変更されたフィールドだけ**検証する:

```javascript
allow update: if isOwner(userId)
  && request.resource.data.keys().hasOnly(["displayName", "createdAt", "iconColor"])
  && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(["displayName"])
      || isValidDisplayName(request.resource.data.displayName));
```

---

## デプロイ前チェック

- [ ] 新コレクション/フィールドを触ったらルールに反映したか
- [ ] `get` のみで足りるか（`list` を開けていないか）
- [ ] 特権フラグはクライアントでなく private + ルール `get()` で検証しているか
- [ ] 書き込みは `hasOnly` でフィールド制限したか
- [ ] エミュレータでルールを検証したか（`firebase emulators:start` / Rules Playground）
- [ ] セキュリティ変更なら `SEC-xxx` コメントと issue があるか
