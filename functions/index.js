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

function timestampToMillis(value) {
  if (!value || typeof value.toMillis !== "function") return null;
  return value.toMillis();
}

function isOrderReadyForRestaurant(order, nowMillis) {
  if (!order || order.status !== "pending") return false;
  if (!Object.prototype.hasOwnProperty.call(order, "restaurantNotifiedAt")) {
    return false;
  }
  if (order.restaurantNotifiedAt) return false;

  const cancelUntilMillis = timestampToMillis(order.canCancelUntil);
  if (cancelUntilMillis === null) return true;

  return cancelUntilMillis <= nowMillis;
}

async function claimRestaurantNotification(db, orderRef, nowMillis) {
  let orderToNotify = null;

  await db.runTransaction(async (transaction) => {
    const orderSnap = await transaction.get(orderRef);
    if (!orderSnap.exists) return;

    const order = orderSnap.data() || {};
    if (!isOrderReadyForRestaurant(order, nowMillis)) return;

    transaction.update(orderRef, {
      restaurantNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    orderToNotify = order;
  });

  return orderToNotify;
}

async function notifyRestaurantAboutOrder(orderId, order) {
  const restaurantId = order.restaurantId;
  if (!restaurantId) return;

  const scheduledForMillis = timestampToMillis(order.scheduledFor);
  const isScheduled =
    scheduledForMillis !== null && scheduledForMillis > Date.now();

  await sendToUserToken(
    restaurantId,
    isScheduled ? "New Scheduled Order" : "New Order",
    `You have a new order #${orderId}`,
    {
      type: "new_order",
      orderId,
      status: order.status || "pending",
      scheduledFor: order.scheduledFor?.toDate?.()?.toISOString?.() || "",
    },
  );
}

exports.notifyRestaurantWhenOrderRevealed = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const nowMillis = Date.now();
    if (
      isOrderReadyForRestaurant(before, nowMillis) ||
      !isOrderReadyForRestaurant(after, nowMillis)
    ) {
      return;
    }

    const order = await claimRestaurantNotification(
      admin.firestore(),
      event.data.after.ref,
      nowMillis,
    );

    if (!order) return;

    await notifyRestaurantAboutOrder(event.params.orderId, order);
  },
);

exports.notifyRestaurantsForReadyOrders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const nowMillis = now.toMillis();

    const readySnap = await db
      .collection("orders")
      .where("status", "==", "pending")
      .where("canCancelUntil", "<=", now)
      .get();

    const claimed = await Promise.all(
      readySnap.docs.map(async (doc) => {
        const order = await claimRestaurantNotification(
          db,
          doc.ref,
          nowMillis,
        );
        return order ? { id: doc.id, order } : null;
      }),
    );

    const toNotify = claimed.filter(Boolean);
    if (toNotify.length === 0) {
      console.log("notifyRestaurantsForReadyOrders: nothing ready");
      return;
    }

    await Promise.all(
      toNotify.map(({ id, order }) => notifyRestaurantAboutOrder(id, order)),
    );

    console.log(
      `notifyRestaurantsForReadyOrders: notified ${toNotify.length} order(s)`,
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

async function cancelGroupOrderWithWalletRefund(db, groupRef, reason) {
  await db.runTransaction(async (transaction) => {
    const groupSnap = await transaction.get(groupRef);
    if (!groupSnap.exists) return;

    const group = groupSnap.data() || {};
    if (group.status === "completed" || group.status === "cancelled") {
      return;
    }

    const membersSnap = await transaction.get(groupRef.collection("members"));

    for (const memberDoc of membersSnap.docs) {
      const member = memberDoc.data() || {};
      const paidAmount = Number(member.paidAmount || 0);
      const payerId = String(member.paymentCustomerId || memberDoc.id);

      if (member.paymentRefunded === true || paidAmount <= 0 || !payerId) {
        continue;
      }

      const walletRef = db
        .collection("users")
        .doc(payerId)
        .collection("wallet")
        .doc("main");

      transaction.set(
        walletRef,
        {
          balance: admin.firestore.FieldValue.increment(paidAmount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      transaction.update(memberDoc.ref, {
        paymentRefunded: true,
        refundedAmount: paidAmount,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.update(groupRef, {
      status: "cancelled",
      cancelledReason: reason,
      cancelledBy: "system",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

exports.autoCloseExpiredGroupOrders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expiredSnap = await db
      .collection("group_orders")
      .where("expiresAt", "<", now)
      .get();

    const activeExpired = expiredSnap.docs.filter((doc) => {
      const status = doc.data()?.status;
      return status !== "completed" && status !== "cancelled";
    });

    if (activeExpired.length === 0) {
      console.log("autoCloseExpiredGroupOrders: nothing expired");
      return;
    }

    await Promise.all(
      activeExpired.map((doc) =>
        cancelGroupOrderWithWalletRefund(db, doc.ref, "expired"),
      ),
    );

    console.log(
      "autoCloseExpiredGroupOrders: closed " +
        `${activeExpired.length} group order(s)`,
    );
  },
);
