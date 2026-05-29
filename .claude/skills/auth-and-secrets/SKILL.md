---
name: auth-and-secrets
description: Apple Sign In の nonce フロー・アカウント削除（トークン revoke）・秘密情報の非コミット（.gitignore）・特権フラグ（isPremium）の二重ゲート検証。認証・課金・機密情報を扱う時に使う。
---

# 認証・機密情報

Apple Sign In・アカウント削除・秘密情報の扱い・特権フラグの守り方。
Firestore ルール側の検証は [security-rules](../security-rules/SKILL.md) を参照。

---

## 1. 絶対にコミットしない秘密情報

`.gitignore` で除外済み。**新しい鍵・設定ファイルを足したら必ず `.gitignore` も更新する。**

| ファイル | 内容 |
|---------|------|
| `GoogleService-Info.plist` | Firebase 設定（ルートに配置、プレースホルダを実ファイルに差し替え） |
| `functions/.env` / `functions/.env.*` | Cloud Functions の環境変数・シークレット |

- API キー・トークン・サービスアカウント JSON はコード／リポジトリに書かない
- ハードコードが必要に見えたら、環境変数か Firebase の仕組み（Secret Manager 等）に逃がす

---

## 2. Apple Sign In（nonce フロー）

`Auth/AppleSignInHelper.swift`:

- `randomNonce()` で `SecRandomCopyBytes` を使った安全な乱数 nonce を生成
- リクエストには `sha256(nonce)` を渡し、Firebase 認証時に **raw nonce** を渡す（リプレイ攻撃対策）

```swift
let nonce = randomNonce()
// ASAuthorizationAppleIDRequest.nonce = sha256(nonce)
// Firebase: OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)
let result = try await AuthState.shared... // rawNonce: nonce を渡す
```

`fullName` は Firebase credential に渡さず（初回しか取れないため別管理）、Firestore の `displayName` で一元管理する。

---

## 3. アカウント削除（トークン revoke 必須）

`AuthState.deleteAccount()` の流れ — Apple 連携アカウントは**トークン revoke が App Store 審査要件**:

1. Apple で**再認証**（`AppleReauthHelper`、新しい nonce で）
2. Firebase を `reauthenticate(with:)` で再認証
3. `Auth.auth().revokeToken(withAuthorizationCode:)` で **Apple トークンを revoke**
4. `user.delete()` で Firebase Auth ユーザー削除
5. Cloud Function `onUserDeleted` が Firestore のデータ（users / friends / heyhos 等）を自動クリーンアップ

> クライアントで Firestore を直接全削除しない。削除トリガーで一元的に掃除する（漏れ・権限問題を防ぐ）。

---

## 4. 特権フラグ（isPremium）の守り方

**クライアントの `StoreService.isPremium` を信頼の起点にしない。**

- StoreKit のエンタイトルメント検証（`Transaction.updates` / `currentEntitlements`）で `isPremium` を決定する
- その結果を `users/{uid}/private/data` の `isPremium` に保存する（`updatePremiumStatus`）
- **サーバー側の制約は Firestore ルールの `isPremiumUser()` が `get()` で検証する**（[security-rules](../security-rules/SKILL.md)）

つまり「letsGo を送れるか」はクライアントの UI ゲート（Paywall 表示）と、ルールの `isPremiumUser` チェックの**二重**で守られている。UI だけのゲートにしない。

---

## チェックリスト

- [ ] 新しい秘密ファイルを `.gitignore` に追加したか
- [ ] 認証フローで nonce（raw / sha256）を正しく使い分けているか
- [ ] アカウント削除で Apple トークン revoke を行っているか
- [ ] 特権フラグはクライアント値でなく private サブドキュメント + ルール検証で守っているか
- [ ] 機密情報を private サブドキュメントに隔離しているか
