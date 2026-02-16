# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 言語設定
- 常に日本語で会話する
- コメントも日本語で記述する
- エラーメッセージの説明も日本語で行う
- ドキュメントも日本語で生成する

## Project Overview

HeyHo is a minimal iOS app (iOS 16+) for sending "Hey" and "Ho" messages to friends with one tap. When you send "Hey" to a friend, they can reply with "Ho", creating a rally conversation. Built with SwiftUI and Firebase.

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
  - `FirestoreService.shared` - all Firestore operations (users, friends, yos)
  - `PushService.shared` - FCM token registration and notification handling
- `Models/` - Data models (`AppUser`, `Yo`) that conform to `Codable` and use `@DocumentID`
- `Features/` - Main UI features
  - `MainTabView` - Tab navigation container (Friends, Inbox, Profile)
  - `Friends/` - Friend list with "Hey" send button
  - `Inbox/` - Received "Hey" messages (uses Firestore real-time listener)
  - `Profile/` - Display name, add friends, sign out

### Navigation Flow

1. `RootView` checks `AuthState.isAuthenticated`
2. If not authenticated → `SignInView` (Apple Sign In)
3. If authenticated → `MainTabView` (3 tabs)

### State Management

- `AuthState` is the global auth state, injected as `@EnvironmentObject`
- Views use `@StateObject` for view-local state and `@State` for simple UI state
- Firestore listeners update `@Published` properties in view models

### Firestore Data Model

```
users/{userId}
  - displayName: string
  - fcmToken: string?
  - createdAt: timestamp
  - friends/{friendId}
      - addedAt: timestamp

yos/{yoId}
  - fromUserId: string
  - toUserId: string
  - messageType: string ("hey" or "ho")
  - createdAt: timestamp (server-side)
```

**Important**: `createdAt` uses `FieldValue.serverTimestamp()`, so it may be `nil` immediately after creation. The Cloud Function handles this when sending notifications.

### Cloud Functions

`functions/src/index.ts` contains a single Firestore trigger (`onYoCreated`) that:
1. Listens for new documents in the `yos` collection
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
- Users can only read/write their own user document
- Friends subcollections are readable/writable by both parties
- Yos can only be created by the sender and read by the recipient
- Yos cannot be updated or deleted

## Testing

Standard XCTest setup in `HeyHo/HeyHoTests/` and `HeyHo/HeyHoUITests/`. Run tests in Xcode (⌘U).

## Code Conventions

- Use `async/await` for all Firebase operations
- Services are singletons accessed via `.shared`
- SwiftUI views use declarative syntax with `@StateObject` and `@State`
- Japanese comments and strings are intentional (app is localized for Japanese users)