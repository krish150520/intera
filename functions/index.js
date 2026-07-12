const functions = require("firebase-functions/v1");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteOldNotifications = onSchedule("every 24 hours", async (event) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const snapshot = await admin.firestore()
        .collection("notifications")
        .where("createdAt", "<", thirtyDaysAgo)
        .get();

    if (snapshot.empty) {
        console.log("No old notifications to delete.");
        return;
    }

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Successfully deleted ${snapshot.size} notifications older than 30 days.`);
});

exports.sendPushNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.data();
    
    if (!notificationData) {
        console.log("No notification data found.");
        return null;
    }

    const recipientId = notificationData.recipientId;
    const title = notificationData.title || "New Notification";
    const body = notificationData.subtitle || "";
    const type = notificationData.type || "";
    const relatedId = notificationData.relatedId || "";

    if (!recipientId) {
        console.log("No recipientId in notification.");
        return null;
    }

    try {
        // Fetch recipient's FCM token from Firestore users collection
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        
        if (!userDoc.exists) {
            console.log(`User document not found for recipientId: ${recipientId}`);
            return null;
        }

        const fcmToken = userDoc.data().fcmToken;

        if (!fcmToken) {
            console.log(`No FCM token registered for recipientId: ${recipientId}`);
            return null;
        }

        // Build the FCM message payload
        const message = {
            token: fcmToken,
            notification: {
                title: title,
                body: body,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: type,
                relatedId: relatedId,
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "intera_default_channel",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
        };

        // Send the push notification using v1 admin API
        const response = await admin.messaging().send(message);
        console.log(`Push notification successfully sent to ${recipientId}. MessageId: ${response}`);
        return response;
    } catch (error) {
        console.error(`Error sending push notification:`, error);
        return null;
    }
});

/**
 * Helper function to clear numeric fields in Firestore in chunks of 500
 */
async function resetKarmaField(field) {
    const db = admin.firestore();
    const query = db.collection("users").where(field, ">", 0).limit(500);
    
    while (true) {
        const snapshot = await query.get();
        if (snapshot.empty) {
            break;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, { [field]: 0 });
        });

        await batch.commit();
        console.log(`Reset ${snapshot.size} users for field: ${field}`);
        
        // Wait briefly to avoid hitting rate limits
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
}

// Reset monthly karma at 00:00 on the 1st of every month
exports.resetMonthlyKarma = onSchedule("0 0 1 * *", async (event) => {
    console.log("Starting monthly karma reset job...");
    await resetKarmaField("karmaEarnedThisMonth");
    await resetKarmaField("beautyPointsThisMonth");
    await resetKarmaField("artPointsThisMonth");
    await resetKarmaField("funnyPointsThisMonth");
    console.log("Monthly karma reset job finished.");
});

// Reset yearly karma at 00:00 on January 1st of every year
exports.resetYearlyKarma = onSchedule("0 0 1 1 *", async (event) => {
    console.log("Starting yearly karma reset job...");
    await resetKarmaField("karmaEarnedThisYear");
    await resetKarmaField("beautyPointsThisYear");
    await resetKarmaField("artPointsThisYear");
    await resetKarmaField("funnyPointsThisYear");
    console.log("Yearly karma reset job finished.");
});