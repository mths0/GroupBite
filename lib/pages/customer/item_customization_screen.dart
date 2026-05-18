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
  final Set<String> _invalidGroupIds = {};

  bool _groupHasSelection(MenuItemOptionGroup group) {
    if (group.multiSelect) {
      final selected = _multiSelections[group.id] ?? <String>{};
      return selected.isNotEmpty;
    }
    final selected = _singleSelections[group.id];
    return selected != null && selected.isNotEmpty;
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

  void _confirm() {
    final missing = <String>{};
    for (final group in widget.item.optionGroups) {
      if (group.isRequired && !_groupHasSelection(group)) {
        missing.add(group.id);
      }
    }

    if (missing.isNotEmpty) {
      setState(() {
        _invalidGroupIds
          ..clear()
          ..addAll(missing);
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

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: widget.item.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: scheme.outline,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.restaurant_menu,
                              color: scheme.outline,
                              size: 48,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      widget.item.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.item.description.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        widget.item.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (widget.item.optionGroups.isNotEmpty)
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                      indent: 20,
                      endIndent: 20,
                    ),
                  for (var i = 0; i < widget.item.optionGroups.length; i++) ...[
                    _OptionGroupSection(
                      group: widget.item.optionGroups[i],
                      invalid: _invalidGroupIds.contains(
                        widget.item.optionGroups[i].id,
                      ),
                      singleSelection:
                          _singleSelections[widget.item.optionGroups[i].id],
                      multiSelection:
                          _multiSelections[widget.item.optionGroups[i].id] ??
                          const <String>{},
                      onSingleChanged: (choiceId) {
                        final groupId = widget.item.optionGroups[i].id;
                        setState(() {
                          _singleSelections[groupId] = choiceId;
                          _invalidGroupIds.remove(groupId);
                        });
                      },
                      onMultiChanged: (choiceId, selected) {
                        final groupId = widget.item.optionGroups[i].id;
                        setState(() {
                          final set =
                              _multiSelections[groupId] ?? <String>{};
                          if (selected) {
                            set.add(choiceId);
                          } else {
                            set.remove(choiceId);
                          }
                          _multiSelections[groupId] = set;
                          if (set.isNotEmpty) {
                            _invalidGroupIds.remove(groupId);
                          }
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _confirm,
                  child: Text(
                    'Add  •  ${finalPrice.toStringAsFixed(2)} SAR',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionGroupSection extends StatelessWidget {
  const _OptionGroupSection({
    required this.group,
    required this.invalid,
    required this.singleSelection,
    required this.multiSelection,
    required this.onSingleChanged,
    required this.onMultiChanged,
  });

  final MenuItemOptionGroup group;
  final bool invalid;
  final String? singleSelection;
  final Set<String> multiSelection;
  final ValueChanged<String> onSingleChanged;
  final void Function(String choiceId, bool selected) onMultiChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = group.isRequired
        ? (invalid ? scheme.error : scheme.error)
        : scheme.onSurfaceVariant;
    final radioColor = invalid ? scheme.error : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: invalid
            ? scheme.errorContainer.withValues(alpha: 0.3)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: invalid ? scheme.error : scheme.outlineVariant,
          width: invalid ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                group.isRequired ? 'Required' : 'Optional',
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (invalid) ...[
            const SizedBox(height: 4),
            Text(
              'Please select an option to continue',
              style: TextStyle(
                color: scheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (!group.multiSelect)
            ...group.choices.map((choice) {
              return _ChoiceRow(
                label: choice.name,
                extraPrice: choice.extraPrice,
                selected: singleSelection == choice.id,
                accentColor: radioColor,
                onTap: () => onSingleChanged(choice.id),
                multi: false,
              );
            }),
          if (group.multiSelect)
            ...group.choices.map((choice) {
              final selected = multiSelection.contains(choice.id);
              return _ChoiceRow(
                label: choice.name,
                extraPrice: choice.extraPrice,
                selected: selected,
                accentColor: radioColor,
                onTap: () => onMultiChanged(choice.id, !selected),
                multi: true,
              );
            }),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.extraPrice,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    required this.multi,
  });

  final String label;
  final double extraPrice;
  final bool selected;
  final Color? accentColor;
  final VoidCallback onTap;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indicatorColor = accentColor ?? scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            _Indicator(
              selected: selected,
              color: indicatorColor,
              multi: multi,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (extraPrice > 0)
              Text(
                '+${extraPrice.toStringAsFixed(2)} SAR',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.selected,
    required this.color,
    required this.multi,
  });

  final bool selected;
  final Color color;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? color : scheme.outline;
    if (multi) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: selected
            ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
            : null,
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            )
          : null,
    );
  }
}
