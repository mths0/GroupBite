import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/add_address_screen.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:yjeek/utils/id_generator.dart';
import 'package:yjeek/utils/validators.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RestaurantRegisterScreen extends StatefulWidget {
  const RestaurantRegisterScreen({super.key, required this.email});
  final String email;

  @override
  State<RestaurantRegisterScreen> createState() =>
      _RestaurantRegisterScreenState();
}

class _RestaurantRegisterScreenState extends State<RestaurantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String? nameErrorText;
  String? phoneErrorText;
  String? errorText;

  final Set<RestaurantTag> _selectedTags = {};
  String? tagsErrorText;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool isLoading = false;
  GeoPoint? _restaurantLocation;
  String _locationPreview = '';
  String? _locationError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void validateData() async {
    setState(() {
      nameErrorText = null;
      phoneErrorText = null;
      tagsErrorText = null;
      _locationError = null;
      errorText = null;
    });

    final nameError = Validators.validateRestaurantName(_nameCtrl.text.trim());
    final phoneError = Validators.validatePhone(_phoneCtrl.text.trim());
    final tagsError = _selectedTags.isEmpty
        ? "Please select at least one category"
        : null;

    if (nameError != null ||
        phoneError != null ||
        tagsError != null ||
        _restaurantLocation == null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        tagsErrorText = tagsError;
        _locationError = _restaurantLocation == null
            ? "Please choose restaurant location on the map."
            : null;
      });
      return;
    }

    await _submit();
  }

  Future<void> _pickLocation() async {
    final existing = _restaurantLocation;
    final initialTarget = existing == null
        ? const LatLng(24.7136, 46.6753)
        : LatLng(existing.latitude, existing.longitude);
    final initialSelection = existing == null
        ? null
        : LatLng(existing.latitude, existing.longitude);

    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialTarget: initialTarget,
          initialSelection: initialSelection,
        ),
      ),
    );

    if (picked == null || !mounted) return;

    final address = await resolveAddressFromLatLng(picked);
    if (!mounted) return;

    setState(() {
      _restaurantLocation = GeoPoint(picked.latitude, picked.longitude);
      _locationPreview = address;
      _locationError = null;
    });
  }

  Future<void> _openCategoriesSheet() async {
    final updated = await showModalBottomSheet<Set<RestaurantTag>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) => _CategoriesPickerSheet(initial: _selectedTags),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(updated);
      if (updated.isNotEmpty) tagsErrorText = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    final db = DatabaseService();

    try {
      final existingPhone = await db.getUserByPhone(_phoneCtrl.text.trim());
      if (existingPhone != null) {
        setState(() {
          isLoading = false;
          phoneErrorText = "Phone number already exists.";
        });
        return;
      }

      final restaurant = Restaurant(
        id: IdGenerator.generateUserId(UserRole.restaurant),
        phone: _phoneCtrl.text.trim(),
        email: widget.email,
        name: _nameCtrl.text.trim(),
        tags: _selectedTags.toList(),
        location: _restaurantLocation,
        createdAt: DateTime.now().toIso8601String(),
        imageUrl:
            'https://images.unsplash.com/photo-1579027989536-b7b1f875659b?q=80&w=2340&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        rating: 5,
        ratingCount: 0,
        deliveryFee: 9,
        isOpen: false,
        hasOffer: false,
      );

      await db.createUser(restaurant.toJson());

      final authService = AuthService();
      await authService.sendMagicLink(widget.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Registration saved. A sign-in link was sent to ${widget.email}",
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        errorText = "Something went wrong. Please try again.";
      });
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = _restaurantLocation != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restaurant Registration',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  'Tell us about your restaurant',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (errorText != null) ...[
                  Text(errorText!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                ],
                _FieldLabel('Phone number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onChanged: (_) {
                    if (phoneErrorText != null) {
                      setState(() => phoneErrorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '5XXXXXXXX',
                    errorText: phoneErrorText,
                  ),
                ),
                const SizedBox(height: 18),
                _FieldLabel('Restaurant name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (nameErrorText != null) {
                      setState(() => nameErrorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. Pizza Palace',
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 22),
                _FieldLabel('Categories'),
                const SizedBox(height: 6),
                Material(
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: _openCategoriesSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedTags.isEmpty
                                  ? 'Tap to pick categories'
                                  : _selectedTags
                                        .map((t) => t.label)
                                        .join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: _selectedTags.isEmpty
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                                fontWeight: _selectedTags.isEmpty
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: scheme.onSurfaceVariant,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (tagsErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      tagsErrorText!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                _FieldLabel('Restaurant location'),
                const SizedBox(height: 6),
                if (hasLocation)
                  Material(
                    color: scheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: InkWell(
                      onTap: _pickLocation,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location selected',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _locationPreview.isEmpty
                                        ? 'Selected location'
                                        : _locationPreview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.edit_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text(
                        'Choose location on map',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerLowest,
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _locationError!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: isLoading ? null : validateData,
                    child: isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CategoriesPickerSheet extends StatefulWidget {
  const _CategoriesPickerSheet({required this.initial});

  final Set<RestaurantTag> initial;

  @override
  State<_CategoriesPickerSheet> createState() => _CategoriesPickerSheetState();
}

class _CategoriesPickerSheetState extends State<_CategoriesPickerSheet> {
  late final Set<RestaurantTag> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Restaurant Categories',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: RestaurantTag.values.map((tag) {
                  final isSelected = _selected.contains(tag);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isSelected,
                    title: Text(
                      tag.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(tag);
                        } else {
                          _selected.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
