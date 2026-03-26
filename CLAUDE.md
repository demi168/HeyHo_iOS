# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 言語設定
- 常に日本語で会話する
- コメントも日本語で記述する
- エラーメッセージの説明も日本語で行う
- ドキュメントも日本語で生成する

## 機能追加時のワークフロー
- 新機能の追加や仕様変更を進める前に、**GitHub Issue 化するかどうかユーザーに確認する**。

## Project Overview

HeyHo is a minimal iOS app (iOS 18.6+) for sending "Hey" and "Ho" messages to friends with one tap. When you send "Hey" to a friend, they can reply with "Ho", creating a rally conversation. Built with SwiftUI and Firebase.

## Build and Run

Open `heyho_ios.xcodeproj` in Xcode and build/run normally (⌘R). The project uses Swift Package Manager for dependencies (Firebase SDK), which Xcode resolves automatically.

For Cloud Functions:
```bash
cd functions
npm install
npm run build           # Compile TypeScript
npm run serve          # Run local emulator
npm run deploy         # Deploy to Firebase
```

## Architecture

### App Structure

The app follows a feature-based organization:

- `App/` - Entry point (`HeyHoApp.swift`) initializes Firebase and `PushService`, then renders `RootView`
- `Auth/` - Authentication logic and UI
  - `AuthState` is an `@ObservableObject` that manages Firebase Auth state and is injected via `@EnvironmentObject`
  - `AppleSignInHelper` handles Apple Sign In credential creation
  - `SignInView` and `SignInWithAppleButton` handle the sign-in UI
- `Services/` - Singleton services for Firebase interactions
  - `FirestoreService.shared` - all Firestore operations (users, friends, heyhos)
  - `PushService.shared` - FCM token registration and notification handling
- `Models/` - Data models (`AppUser`, `HeyHo`) that conform to `Codable` and use `@DocumentID`
- `Features/` - Main UI features
  - `MainTabView` - Entry point (renders FriendsView)
  - `Friends/` - Friend list with "Hey" send button, animation overlay
  - `MyPage/` - Profile editing, friend add (invite code), settings

### Navigation Flow

1. `RootView` checks `AuthState.isAuthenticated` and `isProfileSetupComplete`
2. If not authenticated → `SignInView` (Apple Sign In)
3. If authenticated but profile not set up → `EditProfileView` (initial setup)
4. If authenticated and profile complete → `MainTabView` (2 tabs)

### State Management

- `AuthState` is the global auth state, injected as `@EnvironmentObject`
- Views use `@StateObject` for view-local state and `@State` for simple UI state
- Firestore listeners update `@Published` properties in view models

### Firestore Data Model

```
users/{userId}
  - displayName: string
  - fcmToken: string?
  - inviteCode: string? (6桁の招待コード)
  - createdAt: timestamp
  - friends/{friendId}
      - addedAt: timestamp

inviteCodes/{code}
  - userId: string (招待コードの所有者)

heyhos/{heyhoId}
  - fromUserId: string
  - toUserId: string
  - messageType: string ("hey", "ho", or "letsGo")
  - createdAt: timestamp (server-side)
```

**Important**: `createdAt` uses `FieldValue.serverTimestamp()`, so it may be `nil` immediately after creation. The Cloud Function handles this when sending notifications.

### Cloud Functions

`functions/src/index.ts` contains a single Firestore trigger (`onHeyHoCreated`) that:
1. Listens for new documents in the `heyhos` collection
2. Fetches the recipient's FCM token from Firestore
3. Sends a push notification via Firebase Cloud Messaging

## Firebase Configuration

The project requires `GoogleService-Info.plist` in the root directory. The placeholder file must be replaced with the actual file from Firebase Console.

Firebase services used:
- Authentication (Apple Sign In provider must be enabled)
- Cloud Firestore (deploy `firestore.rules`)
- Cloud Messaging (requires APNs key uploaded to Firebase Console)
- Cloud Functions (deploy `functions/`)

## Security Rules

`firestore.rules` enforces:
- Users: `get` のみ許可（`list` 拒否）、書き込みは本人のみ
- Friends subcollections are readable/writable by both parties
- HeyHos: 送信者かつ友だち関係がある場合のみ作成可、送受信者のみ閲覧可
- HeyHos cannot be updated or deleted
- InviteCodes: `get` のみ許可（`list` 拒否）

## Testing

Standard XCTest setup in `HeyHo/HeyHoTests/` and `HeyHo/HeyHoUITests/`. Run tests in Xcode (⌘U).

## Code Conventions

- Use `async/await` for all Firebase operations
- Services are singletons accessed via `.shared`
- SwiftUI views use declarative syntax with `@StateObject` and `@State`
- Japanese comments and strings are intentional (app is localized for Japanese users)
- **メンテナンス楽ちん設計を絶対キープ**: 値のハードコードを避け、デザイントークン（`SemanticColor`, `SemanticSpacing`等）や定数からの参照にする。同じ値が2箇所以上に出現したら一元管理を検討。「1箇所変えれば全部変わる」を目指す。