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

    const userDoc = await admin.firestore().collection("users").doc(toUserId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;

    const fromUserDoc = await admin.firestore().collection("users").doc(fromUserId).get();
    const fromName = (fromUserDoc.data()?.displayName as string) || "Someone";

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "Yo",
        body: `${fromName} sent you a Yo`,
      },
      data: {
        type: "yo",
        fromUserId,
        yoId: context.params.yoId,
      },
    });
  });
