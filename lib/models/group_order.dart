import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/models/cart_models.dart';
import 'package:food_delivery_platform/models/selected_option_choice.dart';

enum GroupOrderStatus {
  open,
  locked,
  completed,
  cancelled,
}

enum GroupMemberStatus {
  ordering,
  ready,
  paid,
}

class GroupOrder {
  const GroupOrder({
    required this.id,
    required this.hostCustomerId,
    required this.restaurantId,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.deliveryFeeSplit = 'equal',
    this.totalSplitStrategy = 'individual', // 'individual' or 'equal'
    this.timerExtensions = 0,
    this.cancelledReason,
    this.coupon,
  });

  final String id;
  final String hostCustomerId;
  final String restaurantId;
  final String joinCode;
  final GroupOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String deliveryFeeSplit;
  final String totalSplitStrategy;
  final int timerExtensions;
  final String? cancelledReason;
  final Coupon? coupon;

  factory GroupOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final couponMap = data['coupon'];

    return GroupOrder(
      id: doc.id,
      hostCustomerId: data['hostCustomerId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      joinCode: data['joinCode'] ?? '',
      status: GroupOrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupOrderStatus.open,
      ),
      createdAt: createdAt,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          createdAt.add(const Duration(minutes: 10)),
      deliveryFeeSplit: data['deliveryFeeSplit'] ?? 'equal',
      totalSplitStrategy: data['totalSplitStrategy'] ?? 'individual',
      timerExtensions: (data['timerExtensions'] as num?)?.toInt() ?? 0,
      cancelledReason: data['cancelledReason']?.toString(),
      coupon: couponMap is Map<String, dynamic>
          ? Coupon.fromMap(couponMap)
          : null,
    );
  }

  bool get isOpen => status == GroupOrderStatus.open;
  bool get isLocked => status == GroupOrderStatus.locked;
  bool get isCompleted => status == GroupOrderStatus.completed;
}

class GroupOrderMember {
  const GroupOrderMember({
    required this.customerId,
    required this.name,
    required this.status,
    required this.joinedAt,
    this.paidBy,
    this.paymentMode = 'own',
    this.paymentValue,
    this.paymentDeclaredAt,
  });

  final String customerId;
  final String name;
  final GroupMemberStatus status;
  final DateTime joinedAt;
  final String? paidBy;
  final String paymentMode;
  final double? paymentValue;
  final DateTime? paymentDeclaredAt;

  factory GroupOrderMember.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return GroupOrderMember(
      customerId: data['customerId'] ?? doc.id,
      name: data['name'] ?? 'Customer',
      status: GroupMemberStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupMemberStatus.ordering,
      ),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidBy: data['paidBy'],
      paymentMode: (data['paymentMode'] as String?) ?? 'own',
      paymentValue: (data['paymentValue'] as num?)?.toDouble(),
      paymentDeclaredAt: (data['paymentDeclaredAt'] as Timestamp?)?.toDate(),
    );
  }
}

class GroupOrderItem {
  const GroupOrderItem({
    required this.id,
    required this.menuItemId,
    required this.memberId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.selectedOptions,
  });

  final String id;
  final String menuItemId;
  final String memberId;
  final String name;
  final String description;
  final String imageUrl;
  final double unitPrice;
  final int quantity;
  final List<SelectedOptionChoice> selectedOptions;

  double get lineTotal => unitPrice * quantity;

  factory GroupOrderItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return GroupOrderItem(
      id: doc.id,
      menuItemId: data['menuItemId'] ?? '',
      memberId: data['memberId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      selectedOptions: (data['selectedOptions'] as List<dynamic>? ?? [])
          .map((e) => SelectedOptionChoice.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
