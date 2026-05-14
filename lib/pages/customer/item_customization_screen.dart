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
  String? _errorMessage;

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
      setState(() {
        _errorMessage = 'Please complete all required options.';
      });
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: widget.item.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: const Center(
                                child: Icon(Icons.fastfood, size: 48),
                              ),
                            ),
                    ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: scheme.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${widget.item.price.toStringAsFixed(2)} SAR',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Incl. 15% tax',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.item.description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          widget.item.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ),
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
                              _errorMessage = null;
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
                              _errorMessage = null;
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _confirm,
                    child: Text(
                      'Add • ${finalPrice.toStringAsFixed(2)} SAR',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
