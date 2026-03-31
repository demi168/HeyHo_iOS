import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {buildNotification} from "./notificationTemplates";

admin.initializeApp();

/**
 * heyhos ドキュメント作成時、受信者に FCM 通知を送信する。
 */
export const onHeyHoCreated = functions.firestore
  .document("heyhos/{heyhoId}")
  .onCreate(async (snap, context) => {
    const heyHo = snap.data();
    const toUserId = heyHo.toUserId as string;
    const fromUserId = heyHo.fromUserId as string;
    const messageType = (heyHo.messageType as string) || "hey";

    console.log(`メッセージ作成 (${messageType}): ${fromUserId} -> ${toUserId} (ID: ${context.params.heyhoId})`);

    // fcmToken は private サブドキュメントから取得
    const privateDoc = await admin.firestore()
      .collection("users").doc(toUserId)
      .collection("private").doc("data").get();
    const fcmToken = privateDoc.data()?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log(`ユーザー ${toUserId} のFCMトークンが見つかりません`);
      return;
    }

    const fromUserDoc = await admin.firestore().collection("users").doc(fromUserId).get();
    const fromName = (fromUserDoc.data()?.displayName as string) || "Someone";
    const notification = buildNotification(messageType, fromName);

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification,
        data: {
          type: "heyho",
          messageType,
          fromUserId,
          heyhoId: context.params.heyhoId,
        },
      });
      console.log(`FCM通知を送信しました (${messageType}): ${toUserId}`);
    } catch (error) {
      console.error(`FCM送信エラー (${toUserId}):`, error);
    }
  });

/**
 * 友だち追加時、相手側の friends ドキュメントを自動作成する。
 * クライアントは自分側のみ書き込み、このトリガーが相互関係を完成させる。
 */
export const onFriendAdded = functions.firestore
  .document("users/{userId}/friends/{friendId}")
  .onCreate(async (snap, context) => {
    const {userId, friendId} = context.params;

    const reciprocalRef = admin.firestore()
      .collection("users").doc(friendId)
      .collection("friends").doc(userId);

    const existing = await reciprocalRef.get();
    if (existing.exists) {
      console.log(`相互フレンド既存: ${friendId} -> ${userId}`);
      return;
    }

    await reciprocalRef.set({
      addedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`相互フレンド作成: ${friendId} -> ${userId}`);
  });

/**
 * 友だち削除時、相手側の friends ドキュメントも自動削除する。
 */
export const onFriendRemoved = functions.firestore
  .document("users/{userId}/friends/{friendId}")
  .onDelete(async (snap, context) => {
    const {userId, friendId} = context.params;

    const reciprocalRef = admin.firestore()
      .collection("users").doc(friendId)
      .collection("friends").doc(userId);

    const existing = await reciprocalRef.get();
    if (!existing.exists) {
      console.log(`相手側フレンド既に削除済み: ${friendId} -> ${userId}`);
      return;
    }

    await reciprocalRef.delete();
    console.log(`相互フレンド削除: ${friendId} -> ${userId}`);
  });

/**
 * Firebase Auth ユーザー削除時、関連する Firestore データをすべて削除する。
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db = admin.firestore();
  console.log(`ユーザー削除開始: ${uid}`);

  // 1. friends サブコレクション取得 → 相手側の friends からも自分を削除
  const friendsSnap = await db
    .collection("users").doc(uid)
    .collection("friends").get();
  const friendIds = friendsSnap.docs.map((doc) => doc.id);

  const batch1 = db.batch();
  for (const friendId of friendIds) {
    batch1.delete(
      db.collection("users").doc(friendId).collection("friends").doc(uid)
    );
  }
  for (const doc of friendsSnap.docs) {
    batch1.delete(doc.ref);
  }
  await batch1.commit();

  // 2. inviteCodes から自分のコードを削除
  const inviteSnap = await db
    .collection("inviteCodes")
    .where("userId", "==", uid).get();
  const batch2 = db.batch();
  for (const doc of inviteSnap.docs) {
    batch2.delete(doc.ref);
  }
  await batch2.commit();

  // 3. heyhos から自分が関わるメッセージを削除
  const sentSnap = await db
    .collection("heyhos")
    .where("fromUserId", "==", uid).get();
  const receivedSnap = await db
    .collection("heyhos")
    .where("toUserId", "==", uid).get();
  const batch3 = db.batch();
  for (const doc of [...sentSnap.docs, ...receivedSnap.docs]) {
    batch3.delete(doc.ref);
  }
  await batch3.commit();

  // 4. private サブドキュメント削除
  const privateSnap = await db
    .collection("users").doc(uid)
    .collection("private").get();
  const batch4 = db.batch();
  for (const doc of privateSnap.docs) {
    batch4.delete(doc.ref);
  }
  await batch4.commit();

  // 5. users ドキュメント本体を削除
  await db.collection("users").doc(uid).delete();

  console.log(
    `ユーザー削除完了: ${uid} (friends: ${friendIds.length})`
  );
});
