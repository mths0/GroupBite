class MenuItemOptionChoice {
  final String id;
  final String name;
  final double extraPrice;

  MenuItemOptionChoice({
    required this.id,
    required this.name,
    required this.extraPrice,
  });

  factory MenuItemOptionChoice.fromMap(Map<String, dynamic> map) {
    return MenuItemOptionChoice(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      extraPrice: (map['extraPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'extraPrice': extraPrice,
  };
}

class MenuItemOptionGroup {
  final String id;
  final String title;
  final bool isRequired;
  final bool multiSelect;
  final List<MenuItemOptionChoice> choices;

  MenuItemOptionGroup({
    required this.id,
    required this.title,
    required this.isRequired,
    required this.multiSelect,
    required this.choices,
  });

  factory MenuItemOptionGroup.fromMap(Map<String, dynamic> map) {
    return MenuItemOptionGroup(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      isRequired: (map['isRequired'] ?? false) as bool,
      multiSelect: (map['multiSelect'] ?? false) as bool,
      choices: (map['choices'] as List<dynamic>? ?? [])
          .map((e) => MenuItemOptionChoice.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isRequired': isRequired,
    'multiSelect': multiSelect,
    'choices': choices.map((e) => e.toJson()).toList(),
  };
}
