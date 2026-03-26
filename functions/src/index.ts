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
