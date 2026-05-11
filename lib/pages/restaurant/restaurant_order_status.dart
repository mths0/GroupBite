import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/order.dart';

Color restaurantStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Colors.orange;
    case OrderStatus.accepted:
      return Colors.blue;
    case OrderStatus.rejected:
      return Colors.red;
    case OrderStatus.pickedUp:
      return Colors.deepPurple;
    case OrderStatus.delivered:
      return Colors.green;
    case OrderStatus.assigned:
      return Colors.cyan;
    case OrderStatus.cancelled:
      return Colors.grey;
  }
}

String restaurantStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.rejected:
      return 'Rejected';
    case OrderStatus.accepted:
      return 'Accepted';
    case OrderStatus.assigned:
      return 'Assigned';
    case OrderStatus.pickedUp:
      return 'Picked Up';
    case OrderStatus.delivered:
      return 'Delivered';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

String restaurantStatusMessage(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Waiting for restaurant decision';
    case OrderStatus.rejected:
      return 'This order was rejected';
    case OrderStatus.accepted:
      return 'Order accepted. Waiting for driver';
    case OrderStatus.assigned:
      return 'Driver assigned to this order';
    case OrderStatus.pickedUp:
      return 'Order picked up by driver';
    case OrderStatus.delivered:
      return 'Order delivered successfully';
    case OrderStatus.cancelled:
      return 'Order was cancelled';
  }
}
