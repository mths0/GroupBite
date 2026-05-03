class FamilyWallet {
  final String id;
  final String name;
  final String ownerId;
  final String ownerName;
  final double balance;
  final List<String> memberIds;

  const FamilyWallet({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.balance,
    required this.memberIds,
  });

  bool isOwner(String userId) => ownerId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
  bool includes(String userId) => isOwner(userId) || isMember(userId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'balance': balance,
        'memberIds': memberIds,
      };

  factory FamilyWallet.fromMap(Map<String, dynamic> map) {
    final raw = map['memberIds'];
    final members = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>[];

    final balance = map['balance'];
    final balanceDouble = balance is num
        ? balance.toDouble()
        : double.tryParse('$balance') ?? 0.0;

    return FamilyWallet(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Family Wallet').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString(),
      balance: balanceDouble,
      memberIds: members,
    );
  }
}
