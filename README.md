# HeyHo - ショートコミュニケーション iOS アプリ

友だちに「Hey」を1タップで送り、受け取った側は「Ho」で返答できる、ラリー型のミニマルなiOSアプリです。

## 技術スタック
- **UI**: SwiftUI（iOS 16+）
- **認証**: Firebase Auth（Apple Sign In）
- **データ**: Cloud Firestore（users, friends, yos）
- **プッシュ**: Firebase Cloud Messaging（FCM）

## セットアップ

### 1. Firebase プロジェクト
1. [Firebase Console](https://console.firebase.google.com/) でプロジェクトを作成
2. iOS アプリを追加（Bundle ID: `com.example.yo2ios` または任意）
3. **GoogleService-Info.plist** をダウンロードし、`yo2_ios/` 直下に配置（既存のプレースホルダーを上書き）
4. **Authentication** で「Apple」を有効化
5. **Firestore Database** を作成し、`firestore.rules` の内容でルールをデプロイ

### 2. Xcode

1. `heyho_ios.xcodeproj` を開く
2. **Signing & Capabilities** でチームを設定
3. **+ Capability** で以下を追加:
   - **Sign in with Apple**
   - **Push Notifications**
4. 必要に応じて **Background Modes** で「Remote notifications」にチェック
5. 実機またはシミュレータでビルド・実行

### 3. プッシュ通知（FCM）

1. **Apple Developer** で APNs キー（.p8）を作成
2. Firebase Console > プロジェクトの設定 > **Cloud Messaging** で APNs 認証キーをアップロード
3. **Cloud Functions** を有効化し、`functions/` をデプロイ:
   ```bash
   cd functions
   npm install
   npm run deploy
   ```
   （初回は `firebase init` でプロジェクトを紐付けてから `firebase deploy --only functions`）

## プロジェクト構成

- `heyho_ios/App/` — エントリポイント、ルート表示
- `heyho_ios/Auth/` — Apple Sign In、サインイン画面
- `heyho_ios/Models/` — User, Yo（Firestore モデル）
- `heyho_ios/Services/` — FirestoreService, PushService
- `heyho_ios/Features/` — Friends（友だち一覧・Hey送信）、Inbox（受信）、Profile（表示名・友だち追加・ログアウト）

## 使い方

1. 起動後、Apple でサインイン（初回は表示名を入力）
2. プロフィール > 友だちを追加で表示名検索し、追加
3. 友だちタブで「Hey」ボタンをタップして送信
4. 相手はプッシュ通知と受信タブで確認し、「Ho」で返答
5. 「Hey」→「Ho」→「Hey」→「Ho」とラリーが続く

## 注意

- **GoogleService-Info.plist** はプレースホルダーのため、Firebase Console から取得した実ファイルに差し替えてください。
- Firestore の `createdAt` はサーバータイムスタンプのため、初回書き込み直後にクライアントで読むと `null` になる場合があります。Cloud Functions 側では `yo.createdAt` を参照する場合は存在確認を推奨します。
