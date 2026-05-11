const { setGlobalOptions } = require("firebase-functions/v2");
const {
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

// Notifies the restaurant once the customer's cancel window has closed.
// Runs every minute and is idempotent via the `restaurantNotified` flag.
exports.notifyRestaurantOnCancelWindowEnd = onSchedule(
  "every 1 minutes",
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("orders")
      .where("status", "==", "pending")
      .where("canCancelUntil", "<=", now)
      .get();

    if (snap.empty) {
      return;
    }

    for (const doc of snap.docs) {
      const order = doc.data() || {};

      if (order.restaurantNotified === true) continue;

      const restaurantId = order.restaurantId;
      if (!restaurantId) continue;

      try {
        await sendToUserToken(
          restaurantId,
          "New Order",
          `You have a new order #${doc.id}`,
          {
            type: "new_order",
            orderId: doc.id,
            status: order.status || "pending",
          },
        );

        await doc.ref.update({ restaurantNotified: true });
      } catch (err) {
        console.error(`Failed to notify restaurant for order ${doc.id}:`, err);
      }
    }
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
