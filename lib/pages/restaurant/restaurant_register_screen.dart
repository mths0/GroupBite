import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/models/restaurant_tag.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';
import 'package:food_delivery_platform/utils/validators.dart';

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
  CustomerAddress? _selectedLocation;
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
        _selectedLocation?.location == null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        tagsErrorText = tagsError;
        _locationError = _selectedLocation?.location == null
            ? "Please choose restaurant location on the map."
            : null;
      });
      return;
    }

    await _submit();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          existing: _selectedLocation,
          title: 'Restaurant Location',
          showLabelField: false,
          showBuildingDetailsField: false,
          showDefaultToggle: false,
          saveButtonText: 'Save Location',
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _selectedLocation = result;
      _locationError = null;
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
        location: _selectedLocation!.location,
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
    final brand = theme.extension<BrandColors>()!;
    final hasLocation = _selectedLocation?.location != null;
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
                  'Fill restaurant details',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                if (errorText != null) ...[
                  Text(
                    errorText!,
                    style: TextStyle(color: scheme.error),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Phone number (5XXXXXXXX)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    errorText: phoneErrorText,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Restaurant name',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Restaurant categories',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant, width: 1),
                  ),
                  child: Column(
                    children: RestaurantTag.values.map((tag) {
                      final isSelected = _selectedTags.contains(tag);

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isSelected,
                        title: Text(tag.label),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

                if (tagsErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      tagsErrorText!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: Icon(
                      hasLocation ? Icons.location_on : Icons.map_outlined,
                      size: 18,
                      color: hasLocation ? brand.success : null,
                    ),
                    label: Text(
                      hasLocation
                          ? 'Location Selected'
                          : 'Choose Location on Map',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerLowest,
                      foregroundColor: hasLocation
                          ? brand.success
                          : scheme.onSurface,
                      side: BorderSide(
                        color: hasLocation
                            ? brand.success.withValues(alpha: 0.4)
                            : scheme.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.place_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(
                        'Restaurant location',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _selectedLocation!.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _pickLocation,
                      ),
                    ),
                  ),
                ],
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _locationError!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: validateData,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
