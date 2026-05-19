import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';

({Color background, Color foreground}) restaurantStatusColors(
  BuildContext context,
  OrderStatus status,
) {
  final scheme = Theme.of(context).colorScheme;
  final brand = Theme.of(context).extension<BrandColors>()!;
  switch (status) {
    case OrderStatus.pending:
      return (background: brand.offer, foreground: brand.onOffer);
    case OrderStatus.accepted:
      return (
        background: const Color(0xFFDDEBFF),
        foreground: const Color(0xFF1A3D7A),
      );
    case OrderStatus.assigned:
      return (
        background: const Color(0xFFD4EEF1),
        foreground: const Color(0xFF0F5E66),
      );
    case OrderStatus.pickedUp:
      return (
        background: const Color(0xFFFFDDB5),
        foreground: const Color(0xFF7A3E00),
      );
    case OrderStatus.delivered:
      return (
        background: brand.openStatus,
        foreground: brand.onOpenStatus,
      );
    case OrderStatus.rejected:
    case OrderStatus.cancelled:
      return (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
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
