const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

async function sendToUserToken(userId, title, body, data = {}) {
  const userSnap = await admin
    .firestore()
    .collection("users")
    .doc(userId)
    .get();

  if (!userSnap.exists) {
    console.log(`User not found: ${userId}`);
    return;
  }

  const userData = userSnap.data() || {};
  const token = userData.fcmToken;

  if (!token) {
    console.log(`No FCM token for user: ${userId}`);
    return;
  }

  await admin.messaging().send({
    token,
    notification: {
      title,
      body,
    },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    ),
  });

  console.log(`Notification sent to user: ${userId}`);
}

exports.notifyRestaurantOnNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const order = snap.data();
    if (!order) return;

    const restaurantId = order.restaurantId;
    if (!restaurantId) return;

    await sendToUserToken(
      restaurantId,
      "New Order",
      `You have a new order #${event.params.orderId}`,
      {
        type: "new_order",
        orderId: event.params.orderId,
        status: order.status || "pending",
      },
    );
  },
);

exports.notifyCustomerOnOrderStatusChange = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    if (before.status === after.status) {
      return;
    }

    const customerId = after.customerId;
    if (!customerId) return;

    const status = after.status || "pending";

    const statusTitles = {
      pending: "Order Update",
      accepted: "Order Accepted",
      rejected: "Order Rejected",
      assigned: "Driver Assigned",
      pickedUp: "Order Picked Up",
      delivered: "Order Delivered",
    };

    const statusBodies = {
      pending: "Your order status was updated.",
      accepted: "The restaurant accepted your order.",
      rejected: "The restaurant rejected your order.",
      assigned: "A driver has been assigned to your order.",
      pickedUp: "Your order has been picked up and is on the way.",
      delivered: "Your order has been delivered.",
    };

    await sendToUserToken(
      customerId,
      statusTitles[status] || "Order Update",
      statusBodies[status] || "Your order status changed.",
      {
        type: "order_status",
        orderId: event.params.orderId,
        status,
      },
    );
  },
);

// Auto-cancel orders whose stage deadline has passed:
//   * status "pending"  + restaurantRespondBy < now → restaurant didn't reply
//   * status "accepted" + driverAcceptBy     < now → no driver picked it up
// Runs every minute. The Dart client also fires this in a transaction as a
// backup when someone has the app open; both paths converge on the same doc
// guarded by a status check.
exports.autoCancelStaleOrders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const [pendingSnap, acceptedSnap] = await Promise.all([
      db
        .collection("orders")
        .where("status", "==", "pending")
        .where("restaurantRespondBy", "<", now)
        .get(),
      db
        .collection("orders")
        .where("status", "==", "accepted")
        .where("driverAcceptBy", "<", now)
        .get(),
    ]);

    const stale = [...pendingSnap.docs, ...acceptedSnap.docs];
    if (stale.length === 0) {
      console.log("autoCancelStaleOrders: nothing stale");
      return;
    }

    const writer = db.bulkWriter();
    for (const doc of stale) {
      writer.update(doc.ref, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: "system",
      });
    }

    await writer.close();
    console.log(
      `autoCancelStaleOrders: cancelled ${stale.length} order(s) ` +
        `(${pendingSnap.size} pending, ${acceptedSnap.size} accepted)`,
    );
  },
);
