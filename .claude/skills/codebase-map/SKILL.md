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
| `AppLogger.swift` | `os.Logger` のカテゴリ別ラッパー（firestore/push/store/auth/feedback）→ [logging](../logging/SKILL.md) |

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

### Models/（`Foundation` のみ import の純粋ロジック群＝テスト対象。詳細は [testing](../testing/SKILL.md)）
| ファイル | 責務 | テスト |
|---------|------|--------|
| `User.swift` | `AppUser`（`@DocumentID`・displayName・createdAt・iconColor） | — |
| `HeyHo.swift` | `HeyHo` メッセージ（fromUserId/toUserId/messageType/createdAt） | — |
| `MessageType.swift` | `MessageType`（hey/ho/letsGo）・`reply` で返信チェーンを一元管理 | `MessageTypeTests` |
| `InviteCode.swift` | 招待コードの生成・形式チェック（8桁英数字） | `InviteCodeTests` |
| `DisplayNameValidator.swift` | 表示名バリデーション（エラー種別を enum で返す。文言変換は View 側） | `DisplayNameValidatorTests` |
| `IconColorValue.swift` | アイコンカラーの enum ↔ Firestore 文字列変換 | `IconColorValueTests` |
| `GradientPreset.swift` | グラデーションプリセットの型＋データ（`premiumPresets`）。`AppColor.premiumGradientPresets` の実体 | — |
| `PremiumConfig.swift` | `productId`・`isEnabled` など課金設定 | — |

### Features/
| パス | 責務 |
|------|------|
| `MainTabView.swift` | タブの起点（現状 `FriendsView`） |
| `Friends/FriendsView.swift` | 友だちリスト。`FriendsView`(データ) + `FriendsBodyView`(UI) + `FriendRow`。送信ステート `FriendRowState`(sendHey/sendHo/sendLetsGo)。`debugDummyFriends`(DEBUG表示用・実Firestore friendではない) |
| `Friends/HeyHoAnimationOverlay.swift` | 送受信アニメーション（送信シーケンスはキャンセル可能な単一 Task） |
| `MyPage/MyPageView.swift` | マイページ本体（データ読込・アクション）。UI は下記サブ View に委譲 |
| `MyPage/MyPageSections.swift` | `ProfileSectionView` / `InviteCodeSectionView` / `AddFriendSectionView` / `SettingsSectionView`（BodyView・Preview付き） |
| `MyPage/MyPageComponents.swift` | `CapsuleButton` / `UnderlinedText` / `SafariView`（MyPage 共通部品） |
| `MyPage/InviteQRCodeView.swift` | 招待コードのQRシェアカード |
| `MyPage/EditProfileView.swift` | プロフィール編集本体（名前・カラー保存）。UI は下記に委譲 |
| `MyPage/NameInputSection.swift` | 名前入力フォーム（BodyView） |
| `MyPage/IconColorPickerView.swift` | アイコンカラー選択（ソリッド+グラデ グリッド・ランダム生成・BodyView） |
| `Premium/PaywallView.swift` | 課金画面 |
| `Premium/AnimatedGradientFill.swift` | グラデーション描画 |
| `HeyBoyIconView.swift` | ユーザーアイコン。目パチ＝キャンセル可能な Task ループ（`onDisappear` でキャンセル） |
| `IrisLoadingView.swift` | アイリス型ローディング演出（`.irisLoading(isLoading:)` modifier） |

> 旧 `Features/Profile/{ProfileView,AddFriendView}.swift` は未使用のため `_archived/` へ退避済み（コンパイル対象外）。

### DesignTokens/
`AppColor` / `AppSpacing` / `AppTypography` / `AppSize` → 詳細は [design-tokens](../design-tokens/SKILL.md)。
`ColorHex.swift` は `Color(hex:)` / `Color.toHex()` 拡張（モジュール内共有。`AppColor` のトークン定義もこれを使う）。

### HeyHoTests/
独立テストターゲット（ホストなし・dual membership）。`Models/` の純粋ロジックを Swift Testing で検証 → [testing](../testing/SKILL.md)

### functions/
`functions/src/index.ts` に全 Cloud Function。`onHeyHoCreated`（通知送信）・`onFriendAdded` / `onFriendRemoved`・`onUserDeleted`（削除時クリーンアップ）。

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
