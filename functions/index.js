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