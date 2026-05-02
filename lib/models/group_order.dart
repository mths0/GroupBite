import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  final String id;
  final String hostCustomerId;
  final String restaurantId;
  final String joinCode;
  final GroupOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return GroupOrder(
      id: doc.id,
      hostCustomerId: data['hostCustomerId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      joinCode: data['joinCode'] ?? '',
      status: GroupOrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupOrderStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
  });

  final String customerId;
  final String name;
  final GroupMemberStatus status;
  final DateTime joinedAt;

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
  });

  final String id;
  final String menuItemId;
  final String memberId;
  final String name;
  final String description;
  final String imageUrl;
  final double unitPrice;
  final int quantity;

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
    );
  }
}
