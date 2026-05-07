import 'package:food_delivery_platform/models/selected_option_choice.dart';

class ItemCustomizationResult {
  final List<SelectedOptionChoice> selectedOptions;
  final double finalUnitPrice;

  ItemCustomizationResult({
    required this.selectedOptions,
    required this.finalUnitPrice,
  });
}