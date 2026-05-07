import 'package:flutter/material.dart';
import 'package:food_delivery_platform/models/item_customization_result.dart';
import 'package:food_delivery_platform/models/menu_item.dart';
import 'package:food_delivery_platform/models/menu_item_option.dart';
import 'package:food_delivery_platform/models/selected_option_choice.dart';

class ItemCustomizationScreen extends StatefulWidget {
  const ItemCustomizationScreen({
    super.key,
    required this.item,
  });

  final MenuItem item;

  @override
  State<ItemCustomizationScreen> createState() =>
      _ItemCustomizationScreenState();
}

class _ItemCustomizationScreenState extends State<ItemCustomizationScreen> {
  final Map<String, String> _singleSelections = {};
  final Map<String, Set<String>> _multiSelections = {};

  bool _isValid() {
    for (final group in widget.item.optionGroups) {
      if (!group.isRequired) continue;

      if (group.multiSelect) {
        final selected = _multiSelections[group.id] ?? <String>{};
        if (selected.isEmpty) return false;
      } else {
        final selected = _singleSelections[group.id];
        if (selected == null || selected.isEmpty) return false;
      }
    }
    return true;
  }

  List<SelectedOptionChoice> _buildSelectedOptions() {
    final result = <SelectedOptionChoice>[];

    for (final group in widget.item.optionGroups) {
      if (group.multiSelect) {
        final selectedIds = _multiSelections[group.id] ?? <String>{};
        for (final choice in group.choices) {
          if (selectedIds.contains(choice.id)) {
            result.add(
              SelectedOptionChoice(
                groupId: group.id,
                groupTitle: group.title,
                choiceId: choice.id,
                choiceName: choice.name,
                extraPrice: choice.extraPrice,
              ),
            );
          }
        }
      } else {
        final selectedId = _singleSelections[group.id];
        if (selectedId == null) continue;

        for (final choice in group.choices) {
          if (choice.id == selectedId) {
            result.add(
              SelectedOptionChoice(
                groupId: group.id,
                groupTitle: group.title,
                choiceId: choice.id,
                choiceName: choice.name,
                extraPrice: choice.extraPrice,
              ),
            );
            break;
          }
        }
      }
    }

    return result;
  }

  double _calculateFinalPrice() {
    final selectedOptions = _buildSelectedOptions();
    final extras = selectedOptions.fold<double>(
      0.0,
      (sum, option) => sum + option.extraPrice,
    );
    return widget.item.price + extras;
  }

  String _choiceLabel(MenuItemOptionChoice choice) {
    if (choice.extraPrice <= 0) return choice.name;
    return '${choice.name} (+${choice.extraPrice.toStringAsFixed(2)} SAR)';
  }

  void _confirm() {
    if (!_isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required options.'),
        ),
      );
      return;
    }

    final result = ItemCustomizationResult(
      selectedOptions: _buildSelectedOptions(),
      finalUnitPrice: _calculateFinalPrice(),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final finalPrice = _calculateFinalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _confirm,
            child: Text('Add • ${finalPrice.toStringAsFixed(2)} SAR'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.item.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(widget.item.description),
          const SizedBox(height: 16),

          ...widget.item.optionGroups.map((group) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isRequired ? 'Required' : 'Optional',
                      style: TextStyle(
                        color: group.isRequired ? Colors.red : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!group.multiSelect)
                      ...group.choices.map((choice) {
                        return RadioListTile<String>(
                          value: choice.id,
                          groupValue: _singleSelections[group.id],
                          title: Text(_choiceLabel(choice)),
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _singleSelections[group.id] = value;
                              }
                            });
                          },
                        );
                      }),

                    if (group.multiSelect)
                      ...group.choices.map((choice) {
                        final selected =
                            _multiSelections[group.id]?.contains(choice.id) ??
                            false;

                        return CheckboxListTile(
                          value: selected,
                          title: Text(_choiceLabel(choice)),
                          onChanged: (value) {
                            setState(() {
                              final set =
                                  _multiSelections[group.id] ?? <String>{};

                              if (value == true) {
                                set.add(choice.id);
                              } else {
                                set.remove(choice.id);
                              }

                              _multiSelections[group.id] = set;
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
