import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/models/customer_address.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/add_address_screen.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/add_address_screen.dart';
import 'package:yjeek/pages/restaurant/restaurant_dashboard.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:yjeek/pages/support/support_screen.dart';
import 'package:yjeek/utils/validators.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class RestaurantProfile extends StatelessWidget {
  const RestaurantProfile({
    super.key,
    required this.restaurant,
  });

  final Restaurant restaurant;

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
    );

    if (shouldSignOut != true) return;

    try {
      await AuthService().signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: $e')),
      );
    }
  }

  void _openRestaurantInformation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RestaurantInformationPage(restaurant: restaurant),
      ),
    );
  }

  void _openSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportScreen(
          userId: restaurant.id,
          userRole: 'restaurant',
          userName: restaurant.name,
          userEmail: restaurant.email,
        ),
      ),
    );
  }

  Future<void> _updateField(String field, Object value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(restaurant.id)
        .update({field: value});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const RestaurantPageHeader(title: 'Account'),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(restaurant.id)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final current = data != null
                    ? Restaurant.fromMap(data)
                    : restaurant;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: current.imageUrl.isNotEmpty
                                ? Image.network(
                                    current.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.storefront,
                                      size: 44,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                : Icon(
                                    Icons.storefront,
                                    size: 44,
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            current.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            current.email,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (current.ratingCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: scheme.secondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  current.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _SectionCard(
                      children: [
                        _SectionRow(
                          icon: Icons.person_outline,
                          label: 'Account Information',
                          onTap: () => _openRestaurantInformation(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      children: [
                        _SwitchRow(
                          icon: Icons.storefront_outlined,
                          label: 'Restaurant Open',
                          value: current.isOpen,
                          onChanged: (v) => _updateField('isOpen', v),
                        ),
                        const _SectionRowDivider(),
                        _SwitchRow(
                          icon: Icons.local_offer_outlined,
                          label: 'Has Active Offer',
                          value: current.hasOffer,
                          onChanged: (v) => _updateField('hasOffer', v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      children: [
                        _SectionRow(
                          icon: Icons.support_agent_outlined,
                          label: 'Contact Support',
                          onTap: () => _openSupport(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: scheme.onSurface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionRowDivider extends StatelessWidget {
  const _SectionRowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _RestaurantInformationPage extends StatefulWidget {
  const _RestaurantInformationPage({required this.restaurant});

  final Restaurant restaurant;

  @override
  State<_RestaurantInformationPage> createState() =>
      _RestaurantInformationPageState();
}

class _RestaurantInformationPageState
    extends State<_RestaurantInformationPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _deliveryFeeController;
  late Set<RestaurantTag> _selectedTags;

  bool _isInitialLoading = true;
  String? _loadError;

  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _nameErrorText;
  String? _phoneErrorText;
  String? _deliveryFeeErrorText;
  String? _locationErrorText;

  String? _imageUrl;
  String? _locationPreview;
  GeoPoint? _restaurantLocation;
  File? _selectedImageFile;

  final ImagePicker _picker = ImagePicker();

  DocumentReference<Map<String, dynamic>> get _restaurantDoc =>
      FirebaseFirestore.instance.collection('users').doc(widget.restaurant.id);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _deliveryFeeController = TextEditingController();

    _selectedTags = {};
    _imageUrl = null;

    _loadRestaurantData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantData() async {
    setState(() {
      _isInitialLoading = true;
      _loadError = null;
    });

    try {
      final snapshot = await _restaurantDoc.get();
      final data = snapshot.data();

      if (data == null) {
        setState(() {
          _loadError = 'Restaurant data not found';
          _isInitialLoading = false;
        });
        return;
      }

      final restaurant = Restaurant.fromMap(data);

      _nameController.text = restaurant.name;
      _phoneController.text = restaurant.phone;
      _deliveryFeeController.text = restaurant.deliveryFee.toStringAsFixed(0);
      _selectedTags = restaurant.tags.toSet();
      _imageUrl = restaurant.imageUrl;
      _restaurantLocation = restaurant.location;
      _locationPreview = restaurant.location == null
          ? null
          : (restaurant.locationAddress.isNotEmpty
              ? restaurant.locationAddress
              : 'Restaurant location selected');
      setState(() {
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load restaurant data';
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() {
      _selectedImageFile = File(picked.path);
    });
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_selectedImageFile == null) return _imageUrl;

    setState(() => _isUploadingImage = true);

    try {
      final path =
          'restaurants/${widget.restaurant.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child(path);

      final uploadTask = ref.putFile(
        _selectedImageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Storage error code: ${e.code}');
      debugPrint('Storage error message: ${e.message}');

      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: ${e.message ?? e.code}')),
      );
      return null;
    } catch (e) {
      debugPrint('Unexpected upload error: $e');

      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
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
    setState(() => _selectedTags = updated);
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
      _locationErrorText = null;
    });
  }

  Future<void> _saveProfile() async {
    final nameError = Validators.validateRestaurantName(_nameController.text);
    final phoneError = Validators.validatePhone(_phoneController.text);
    final feeText = _deliveryFeeController.text.trim();
    final fee = double.tryParse(feeText);
    String? feeError;
    if (feeText.isEmpty) {
      feeError = 'Delivery fee is required';
    } else if (fee == null) {
      feeError = 'Enter a valid number';
    } else if (fee < 0) {
      feeError = 'Delivery fee cannot be negative';
    }

    if (nameError != null ||
        phoneError != null ||
        feeError != null ||
        _restaurantLocation == null) {
      setState(() {
        _nameErrorText = nameError;
        _phoneErrorText = phoneError;
        _deliveryFeeErrorText = feeError;
        _locationErrorText = _restaurantLocation == null
            ? 'Please choose restaurant location on the map.'
            : null;
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deliveryFee = fee!;

      final tags = _selectedTags.map((e) => e.name).toList();

      final uploadedImageUrl = await _uploadImageIfNeeded();
      if (!mounted) return;

      if (_selectedImageFile != null && uploadedImageUrl == null) {
        setState(() => _isSaving = false);
        return;
      }

      await _usersCollection.doc(widget.restaurant.id).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'deliveryFee': deliveryFee,
        'tags': tags,
        'location': _restaurantLocation,
        'locationAddress': _locationPreview ?? '',
        'imageUrl': uploadedImageUrl ?? _imageUrl ?? '',
      });

      if (!mounted) return;

      setState(() {
        _imageUrl = uploadedImageUrl;
        _selectedImageFile = null;
        _nameErrorText = null;
        _phoneErrorText = null;
        _deliveryFeeErrorText = null;
        _locationErrorText = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant profile updated successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = _restaurantLocation != null;

    if (_isInitialLoading) {
      return Scaffold(
        appBar: _buildAppBar(theme, scheme),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: _buildAppBar(theme, scheme),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(theme, scheme),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _selectedImageFile != null
                            ? Image.file(
                                _selectedImageFile!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : (_imageUrl != null && _imageUrl!.isNotEmpty)
                            ? Image.network(
                                _imageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _imagePlaceholder(scheme),
                              )
                            : _imagePlaceholder(scheme),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isUploadingImage ? null : _pickImage,
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(
                            _isUploadingImage ? 'Uploading…' : 'Upload Image',
                            style: const TextStyle(
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _SheetLabel('Restaurant Name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Restaurant Name',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    errorText: _nameErrorText,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetLabel('Email Address'),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(
                    text: widget.restaurant.email,
                  ),
                  enabled: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: scheme.surfaceContainer,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetLabel('Phone Number'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: InputDecoration(
                    hintText: '5XXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    errorText: _phoneErrorText,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetLabel('Restaurant ID'),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(
                    text: widget.restaurant.id,
                  ),
                  enabled: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: scheme.surfaceContainer,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetLabel('Delivery Fee (SAR)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _deliveryFeeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixIcon: const Icon(Icons.attach_money),
                    errorText: _deliveryFeeErrorText,
                  ),
                ),
                const SizedBox(height: 14),

                _SheetLabel('Restaurant Categories'),
                const SizedBox(height: 6),
                Material(
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant, width: 1),
                  ),
                  child: InkWell(
                    onTap: _openCategoriesSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _selectedTags.isEmpty
                                  ? 'Tap to pick categories'
                                  : _selectedTags.map((t) => t.label).join(', '),
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
                const SizedBox(height: 14),

                _SheetLabel('Restaurant Location'),
                const SizedBox(height: 6),
                Material(
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant, width: 1),
                  ),
                  child: InkWell(
                    onTap: _pickLocation,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasLocation
                                      ? 'Restaurant location'
                                      : 'No location set',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasLocation
                                      ? (_locationPreview ??
                                          'Restaurant location selected')
                                      : 'Tap to set the restaurant location on the map',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                if (_locationErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _locationErrorText!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, color: scheme.outlineVariant),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: (_isSaving || _isUploadingImage)
                        ? null
                        : _saveProfile,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme scheme) {
    return AppBar(
      title: Text(
        'Account Information',
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
    );
  }

  Widget _imagePlaceholder(ColorScheme scheme) {
    return Container(
      width: 120,
      height: 120,
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(Icons.image, size: 40, color: scheme.onSurfaceVariant),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
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
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save',
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
    );
  }
}
