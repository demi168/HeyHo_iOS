# 友だちリスト「Hayed / 未返信ハイライト」仕様と実装プラン

## 仕様の整理

| 状態 | 表示 | ボタン | 行の見た目 |
|------|------|--------|------------|
| 自分が Hey を送り、相手からまだ Ho が返ってきていない | 「Hayed」 | 押せない（disabled） | **ハイライト** |
| 相手から Ho が返ってきた（またはまだやりとりがない） | 「Hey」 | 押せる（enabled） | 通常 |

**判定ロジック**

- 各友だちとの「**最後の1件**」の heyho を見る。
- **最後が「自分 → その友だち」かつ messageType == hey**  
  → 「Hey を送ったがまだ Ho が返ってきていない」＝ **未返信**  
  → ボタン「Hayed」・disabled・行をハイライト。
- 上記以外（最後が「友だち → 自分」、または「自分 → 友だち」で ho、またはやりとりなし）  
  → **送信可能**  
  → ボタン「Hey」・enabled・通常表示。

---

## 実装プラン

### 1. FirestoreService の追加 API

**1-1. 2人の最後の1件を取得（内部用）**

- `getLastHeyHo(me: String, friendId: String) async throws -> HeyHo?`
- 既存の `getNextMessageType` で使っているクエリと同じでよい。  
  `heyhos` で `fromUserId in [me, friendId]`, `toUserId in [me, friendId]`, `createdAt` 降順, limit 1。

**1-2. 「未返信」の友だち ID 一覧を取得**

- `getWaitingForReplyFriendIds(userId: String, friendIds: [String]) async throws -> Set<String>`
- 各 `friendId` について `getLastHeyHo(me, friendId)` を呼ぶ。
- 結果が「自分が from かつ messageType == .hey」なら、その friendId を Set に追加して返す。
- 友だち数が多くなければ、ループで順次 await で十分。必要なら `TaskGroup` で並列化。

### 2. FriendsView の変更

**2-1. 状態**

- `waitingForReplyFriendIds: Set<String>` を追加。  
  「未返信」（Hayed 表示・disabled・ハイライト）にしたい友だちの ID の集合。

**2-2. 取得タイミング**

- **初回・画面表示**: `loadFriends()` で友だち一覧取得後、  
  `getWaitingForReplyFriendIds(userId: uid, friendIds: friends.map(\.id).compactMap { $0 })` を呼び、  
  `waitingForReplyFriendIds` を更新。
- **プルで更新**: `refreshable` で同じく友だち再取得 → そのあと `getWaitingForReplyFriendIds` を再実行し、`waitingForReplyFriendIds` を更新。
- **返信が来たとき**: 自分あての heyho が増えたタイミングで「未返信」を再計算したいので、  
  **自分が受信側の heyhos**（`toUserId == me`）の **リスナー** を1本張る。  
  リスナーが fire したら `getWaitingForReplyFriendIds` を再実行し、`waitingForReplyFriendIds` を更新。  
  （相手が Ho を返すと、そのドキュメントは toUserId == me なので、このリスナーで検知できる。）

**2-3. FriendRow に渡す値**

- `isWaitingForReply: Bool`  
  ＝ `friend.id` が `waitingForReplyFriendIds` に含まれるか。
- `justSent: Bool` は現状どおり（直前に送った直後の短いフィードバック用）。

**2-4. FriendRow の表示**

- `isWaitingForReply == true` のとき  
  - ボタン文言: **「Hayed」**  
  - ボタン: **disabled**  
  - 行: **ハイライト**（例: `.listRowBackground(Color.yellow.opacity(0.2))` や `.listRowBackground(Color.orange.opacity(0.15))` など、未返信であることが分かる色）。
- `isWaitingForReply == false` のとき  
  - ボタン文言: **「Hey」**（`justSent` のときだけ「送信済み ✓」など現行どおりでも可）。  
  - ボタン: **enabled**  
  - 行: 通常（ハイライトなし）。

### 3. データフロー（イメージ）

```
[友だち一覧]
  → loadFriends() で friends 取得
  → getWaitingForReplyFriendIds(me, friendIds) で「未返信」の Set 取得
  → waitingForReplyFriendIds を更新
  → 各 FriendRow に isWaitingForReply を渡して表示

[相手が Ho を返した]
  → heyhos (toUserId == me) のリスナーが fire
  → getWaitingForReplyFriendIds を再実行
  → waitingForReplyFriendIds を更新
  → 該当行が Hayed → Hey に戻り、enabled・ハイライト解除
```

### 4. 注意点・確認

- **getNextMessageType** は `sendHeyHo` 専用のままにしてよい。  
  「未返信」判定用の「最後の1件」は `getLastHeyHo`（と `getWaitingForReplyFriendIds`）で行う。
- Firestore の **ルール**: `heyhos` の read で「toUserId == me または fromUserId == me」が許可されているか確認。  
  自分が送受信したやりとりだけ読めればよい。
- ハイライト色はデザインに合わせて調整（黄色・オレンジ・グレーなど）。

---

## 実装順序

1. FirestoreService に `getLastHeyHo` と `getWaitingForReplyFriendIds` を追加する。
2. FriendsView で `waitingForReplyFriendIds` を保持し、`loadFriends` / refresh 時に取得する。
3. FriendRow に `isWaitingForReply` を渡し、「Hayed」・disabled・ハイライトを実装する。
4. FriendsView で「自分が受信した heyhos」のリスナーを張り、更新時に `getWaitingForReplyFriendIds` を再実行する。

この順で進めれば、仕様どおり「Hey を送ったリストは Hayed で disabled・未返信はハイライト」「Ho が返ってきたら enabled に戻る」が実現できます。
