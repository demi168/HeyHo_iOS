# HeyHo — ショートコミュニケーション iOS アプリ

友だちに「**Hey**」を1タップで送り、受け取った側は「**Ho**」で返す。  
さらに「**Let's Go!**」へと続くラリー型のミニマルな iOS アプリです。

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| UI | SwiftUI（iOS 18.6+） |
| 認証 | Firebase Auth（Apple Sign In） |
| データ | Cloud Firestore |
| プッシュ通知 | Firebase Cloud Messaging（FCM） |
| サーバーサイド | Firebase Cloud Functions（TypeScript） |
| 依存管理 | Swift Package Manager（Firebase iOS SDK） |

## アーキテクチャ

### ディレクトリ構成

```
heyho_ios/
├── App/               # エントリポイント（HeyHoApp, RootView）
├── Auth/              # Apple Sign In、サインイン画面、AuthState（@EnvironmentObject）
├── Models/            # 純粋データモデル・バリデーション（Firestore非依存ロジックはここに集約）
├── Services/          # Firebase 操作・外部連携のシングルトン群
│   ├── FirestoreService.swift   # 全 Firestore 読み書き
│   ├── RallyService.swift       # ラリー状態管理・リアルタイム受信（heyhos 購読）
│   ├── PushService.swift        # FCM トークン登録・通知ハンドリング
│   ├── ShareService.swift       # シェア機能
│   ├── StoreService.swift       # StoreKit（課金 isEnabled=false で現在無効）
│   └── FeedbackService.swift    # フィードバック送信
├── Features/
│   ├── Friends/       # 友だち一覧・Hey 送信・受信アニメーション
│   ├── MyPage/        # プロフィール編集・友だち追加（招待コード/QR）・設定
│   └── Premium/       # プレミアム機能（現在無効：PremiumConfig.isEnabled = false）
├── DesignTokens/      # カラー・スペーシング・タイポグラフィトークン
└── Localizable.xcstrings  # 文言管理（String Catalog）
functions/
├── src/index.ts       # Cloud Functions（onHeyHoCreated, onFriendAdded）
└── src/notificationTemplates.ts
```

### ナビゲーションフロー

```
RootView
 ├─ 未認証 → SignInView（Apple Sign In）
 ├─ 認証済・プロフィール未設定 → EditProfileView（初回セットアップ）
 └─ 認証済・設定完了 → FriendsView（単一画面構成）
                          └─ モーダル: MyPageView / AddFriendSheetView
```

### ラリーの仕組み

メッセージタイプは `hey → ho → letsGo → hey → …` のサイクルで循環します。

| 送るもの | 返せるもの |
|----------|-----------|
| Hey | Ho |
| Ho | Let's Go! |
| Let's Go! | Hey |

`RallyService` が Firestore `heyhos` コレクションをリアルタイム購読し、受信イベントを `@Published` で View に伝達します。チュートリアルボット「HeyBoy」がアプリ内に常駐しており、友だちがいない新規ユーザーもすぐにラリーを体験できます。

### 状態管理

- `AuthState`（`@EnvironmentObject`）— グローバルな認証状態
- `RallyService`（`@EnvironmentObject`）— ラリー状態・リアルタイム受信
- `StoreService`（`@EnvironmentObject`）— StoreKit 状態（現在無効）
- View ローカルは `@StateObject` / `@State`

## Firestore データモデル

```
users/{userId}
  - displayName: string           # 6〜16文字
  - iconColor: string?            # ソリッド hex / "gradient:..." / "gradient_custom:..."
  - createdAt: timestamp

  /private/data                   # 本人のみアクセス可
    - fcmToken: string?
    - inviteCode: string?          # 6文字英数字
    - isPremium: bool?

  /friends/{friendId}
    - addedAt: timestamp

inviteCodes/{code}
  - userId: string

heyhos/{heyhoId}
  - fromUserId: string
  - toUserId: string
  - messageType: string           # "hey" | "ho" | "letsGo"
  - createdAt: timestamp          # FieldValue.serverTimestamp()（初回はnilになる場合あり）
```

## Cloud Functions

| 関数 | トリガー | 処理内容 |
|------|----------|----------|
| `onHeyHoCreated` | `heyhos/{id}` 作成 | 受信者の FCM トークンを取得してプッシュ通知を送信 |
| `onFriendAdded` | `users/{id}/friends/{id}` 作成 | 相手側の friends ドキュメントを自動作成（双方向関係の完成） |

## セットアップ

### 1. Firebase プロジェクト

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクトを作成
2. iOS アプリを追加（Bundle ID: `com.demiflare168.HeyHo`）
3. **GoogleService-Info.plist** をダウンロードし、`heyho_ios/` 直下に配置（既存プレースホルダーを上書き）
4. **Authentication** で「Apple」プロバイダを有効化
5. **Firestore Database** を作成し、`firestore.rules` をデプロイ

### 2. Xcode

1. `heyho_ios.xcodeproj` を開く（SPM 依存は自動解決）
2. **Signing & Capabilities** でチームを設定
3. **+ Capability** で以下を追加:
   - Sign in with Apple
   - Push Notifications
4. 必要に応じて **Background Modes** → 「Remote notifications」にチェック
5. 実機またはシミュレータでビルド・実行（⌘R）

### 3. プッシュ通知（FCM）

1. Apple Developer で APNs キー（.p8）を作成
2. Firebase Console → プロジェクトの設定 → **Cloud Messaging** で APNs 認証キーをアップロード
3. Cloud Functions をデプロイ:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## テスト

ユニットテストは **Swift Testing**（`import Testing` / `@Test` / `#expect`）で `HeyHoTests/` に置きます。  
テスト対象は `Models/` 配下の純粋ロジック（Firestore 非依存）に限定します。

```bash
xcodebuild test -project heyho_ios.xcodeproj -scheme HeyHo \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HeyHoTests
```

UI 挙動の確認は手動操作 + `log stream` / `simctl screenshot` で行います。

## テスト用ダミーアカウントの作成

Firestore に直接作成することで、実機なしでも友だち追加フローを検証できます。

1. Firebase Console → **Firestore Database**
2. `users` コレクションにドキュメントを追加:
   - ドキュメントID: 任意（例: `testuser001`）
   - `displayName` (string): `"TestUser"`
   - `iconColor` (string): `"FF6B6B"`
   - `createdAt` (timestamp): 現在時刻
3. そのドキュメント内に `private/data` サブコレクションを追加:
   - `inviteCode` (string): 任意の6文字英数字（例: `"ABC123"`）
4. `inviteCodes` コレクションにドキュメントを追加:
   - ドキュメントID: 上で設定した招待コード（例: `ABC123`）
   - `userId` (string): `"testuser001"`

アプリから招待コードを入力すれば、ダミーアカウントと友だちになれます。

## 注意事項

- **GoogleService-Info.plist** はプレースホルダーです。Firebase Console から取得した実ファイルに差し替えてください。
- `heyhos.createdAt` はサーバータイムスタンプのため、書き込み直後にクライアントで読むと `nil` になる場合があります。Cloud Functions 内でこのフィールドを参照する際は存在確認を行ってください。
- 課金機能（プレミアムカラー・グラデーション）は `PremiumConfig.isEnabled = false` で現在全無効です。有効化する場合はこのフラグを `true` に変更するだけで関連 UI・StoreKit 監視が復活します。
- `letsGo` メッセージはプレミアムフラグと無関係に**全ユーザーが無料で送信可能**です。
