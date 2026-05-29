---
name: codebase-map
description: HeyHo iOS プロジェクトのファイル構成・責務・画面遷移・共通部品・データモデルの地図。「あの処理どこ？」を grep で探す前、コードベース全体を把握したい時に最初に読む。
---

# コードベースマップ

> このファイルの目的は **再探索コストの削減**。「あの処理どこ？」を `grep`/`find` で探す前にここを見る。
> ファイルを追加・移動したらこの表を更新する。

iOS 18.6+ / SwiftUI / Firebase。エントリは `App/HeyHoApp.swift`。

---

## 画面遷移の起点

`RootView`（`App/RootView.swift`）が `AuthState` を見て分岐:

1. 未認証 → `SignInView`（Apple Sign In）
2. 認証済み・プロフィール未設定 → `EditProfileView`（初期設定）
3. 認証済み・設定完了 → `MainTabView` → `FriendsView`

---

## ディレクトリと責務

### App/
| ファイル | 責務 |
|---------|------|
| `HeyHoApp.swift` | `@main`。`FirebaseApp.configure()` → `PushService` / `StoreService` の `configure()` を起動 |
| `RootView.swift` | 認証状態による画面分岐 |

### Auth/
| ファイル | 責務 |
|---------|------|
| `AuthState.swift` | `@EnvironmentObject`。認証状態・`currentUser`/`currentUserId` キャッシュ・サインイン/アウト・アカウント削除 |
| `AppleSignInHelper.swift` | `randomNonce()` / `sha256()` / 再認証ヘルパー（`AppleReauthHelper`） |
| `SignInView.swift` | サインイン画面 |
| `SignInWithAppleButton.swift` | Apple ボタン UI |

### Services/（すべて `.shared` シングルトン）
| ファイル | 責務 |
|---------|------|
| `FirestoreService.swift` | Firestore 全操作（users / friends / heyhos / inviteCodes / private サブドキュメント） |
| `PushService.swift` | FCM トークン登録・通知ハンドリング（`UNUserNotificationCenter` / `Messaging` delegate） |
| `StoreService.swift` | `@EnvironmentObject`。StoreKit 課金・`isPremium`・エンタイトルメント検証 |
| `FeedbackService.swift` | サウンド（`Resources/Sounds/`）・ハプティクス |
| `ShareService.swift` | 招待シェア。`AppURL`（privacy/terms/commercial/appStore）・`ShareConstants` を保持 |

### Models/
| ファイル | 責務 |
|---------|------|
| `User.swift` | `AppUser`（`@DocumentID`・displayName・createdAt・iconColor） |
| `HeyHo.swift` | `HeyHo` メッセージ・`MessageType`（hey/ho/letsGo） |
| `IconColorValue.swift` | アイコンカラーの enum ↔ Firestore 文字列変換 |
| `PremiumConfig.swift` | `productId` など課金設定 |

### Features/
| パス | 責務 |
|------|------|
| `MainTabView.swift` | タブの起点（現状 `FriendsView`） |
| `Friends/FriendsView.swift` | 友だちリスト。`FriendsView`(データ) + `FriendsBodyView`(UI) + `FriendRow`。送信ステート `FriendRowState`(sendHey/sendHo/sendLetsGo) |
| `Friends/HeyHoAnimationOverlay.swift` | 送受信アニメーション |
| `MyPage/MyPageView.swift` | プロフィール・招待コード・友だち追加・設定・サインアウト/削除 |
| `MyPage/EditProfileView.swift` | 名前・アイコンカラー編集 |
| `Profile/ProfileView.swift`, `Profile/AddFriendView.swift` | プロフィール表示・友だち追加 |
| `Premium/PaywallView.swift` | 課金画面 |
| `Premium/AnimatedGradientFill.swift` | グラデーション描画 |
| `IrisLoadingView.swift` | アイリス型ローディング演出（`.irisLoading(isLoading:)` modifier） |

### DesignTokens/
`AppColor` / `AppSpacing` / `AppTypography` / `AppSize` → 詳細は [design-tokens](../design-tokens/SKILL.md)

### functions/
`functions/src/index.ts` に全 Cloud Function。`onHeyHoCreated`（通知送信）・`onUserDeleted`（削除時クリーンアップ）など。

---

## よく使う共通部品

| 名前 | 場所 | 用途 |
|------|------|------|
| `HeyBoyIconView` | ルート `HeyBoyIconView.swift` | ユーザーアイコン（色・プレミアムバッジ） |
| `.errorAlert($errorMessage)` | View Modifier | エラー表示の共通化 |
| `.irisLoading(isLoading:)` | View Modifier | ローディング演出 |
| `IconColorValue(firestoreString:)` | Models | アイコンカラーのパース |

---

## Firestore データモデル

```
users/{userId}              displayName, createdAt, iconColor
  private/data              fcmToken, inviteCode, isPremium（本人のみ）
  friends/{friendId}        addedAt
inviteCodes/{code}          userId
heyhos/{heyhoId}            fromUserId, toUserId, messageType, createdAt
```

セキュリティルールは [security-rules](../security-rules/SKILL.md) を参照。
