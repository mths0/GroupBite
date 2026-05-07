class SelectedOptionChoice {
  final String groupId;
  final String groupTitle;
  final String choiceId;
  final String choiceName;
  final double extraPrice;

  SelectedOptionChoice({
    required this.groupId,
    required this.groupTitle,
    required this.choiceId,
    required this.choiceName,
    required this.extraPrice,
  });

  factory SelectedOptionChoice.fromMap(Map<String, dynamic> map) {
    return SelectedOptionChoice(
      groupId: (map['groupId'] ?? '').toString(),
      groupTitle: (map['groupTitle'] ?? '').toString(),
      choiceId: (map['choiceId'] ?? '').toString(),
      choiceName: (map['choiceName'] ?? '').toString(),
      extraPrice: (map['extraPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupTitle': groupTitle,
        'choiceId': choiceId,
        'choiceName': choiceName,
        'extraPrice': extraPrice,
      };
}