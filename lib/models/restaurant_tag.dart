enum RestaurantTag {
  burger,
  shawarma,
  pizza,
  desserts,
  coffee,
  seafood,
  traditional,
  sandwiches,
  fastFood,
  beverages,
  breakfast,
  healthy,
  other,
  sushi,
  japanese,
}

extension RestaurantTagX on RestaurantTag {
  String get label {
    switch (this) {
      case RestaurantTag.burger:
        return 'Burger';
      case RestaurantTag.shawarma:
        return 'Shawarma';
      case RestaurantTag.pizza:
        return 'Pizza';
      case RestaurantTag.desserts:
        return 'Desserts';
      case RestaurantTag.coffee:
        return 'Coffee';
      case RestaurantTag.seafood:
        return 'Seafood';
      case RestaurantTag.traditional:
        return 'Traditional';
      case RestaurantTag.sandwiches:
        return 'Sandwiches';
      case RestaurantTag.fastFood:
        return 'Fast Food';
      case RestaurantTag.beverages:
        return 'Beverages';
      case RestaurantTag.breakfast:
        return 'Breakfast';
      case RestaurantTag.healthy:
        return 'Healthy';
      case RestaurantTag.sushi:
        return 'Sushi';
      case RestaurantTag.japanese:
        return 'Japanese';
      case RestaurantTag.other:
        return 'Other';
    }
  }

  static RestaurantTag? fromString(String value) {
    for (final tag in RestaurantTag.values) {
      if (tag.name == value) return tag;
    }
    return null;
  }
}
