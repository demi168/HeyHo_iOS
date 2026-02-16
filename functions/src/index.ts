import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * When a document is created in `yos`, send an FCM notification to the recipient.
 * The client only writes to Firestore; this function sends the push.
 */
export const onYoCreated = functions.firestore
  .document("yos/{yoId}")
  .onCreate(async (snap, context) => {
    const yo = snap.data();
    const toUserId = yo.toUserId as string;
    const fromUserId = yo.fromUserId as string;
    const messageType = (yo.messageType as string) || "hey";

    console.log(`メッセージ作成 (${messageType}): ${fromUserId} -> ${toUserId} (ID: ${context.params.yoId})`);

    const userDoc = await admin.firestore().collection("users").doc(toUserId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log(`ユーザー ${toUserId} のFCMトークンが見つかりません`);
      return;
    }

    const fromUserDoc = await admin.firestore().collection("users").doc(fromUserId).get();
    const fromName = (fromUserDoc.data()?.displayName as string) || "Someone";

    const messageText = messageType === "hey" ? "Hey" : "Ho";

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: messageText,
          body: `${fromName}から${messageText}が届きました`,
        },
        data: {
          type: "yo",
          messageType,
          fromUserId,
          yoId: context.params.yoId,
        },
      });
      console.log(`FCM通知を送信しました (${messageType}): ${toUserId}`);
    } catch (error) {
      console.error(`FCM送信エラー (${toUserId}):`, error);
    }
  });
