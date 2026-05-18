class SavedCard {
  final String id;
  final String last4;
  final String expiry;
  final String holderName;
  final bool isDefault;

  const SavedCard({
    required this.id,
    required this.last4,
    required this.expiry,
    required this.holderName,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'last4': last4,
        'expiry': expiry,
        'holderName': holderName,
        'isDefault': isDefault,
      };

  factory SavedCard.fromMap(Map<String, dynamic> map) {
    return SavedCard(
      id: (map['id'] ?? '').toString(),
      last4: (map['last4'] ?? '').toString(),
      expiry: (map['expiry'] ?? '').toString(),
      holderName: (map['holderName'] ?? '').toString(),
      isDefault: (map['isDefault'] ?? false) == true,
    );
  }

  static String last4FromNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  }
}
