import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/models/restaurant_tag.dart';
import 'package:food_delivery_platform/pages/customer/add_address_screen.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/pages/support/support_screen.dart';
import 'package:food_delivery_platform/utils/validators.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';
import 'package:image_picker/image_picker.dart';

class RestaurantProfile extends StatefulWidget {
  const RestaurantProfile({
    super.key,
    required this.restaurant,
  });

  final Restaurant restaurant;

  @override
  State<RestaurantProfile> createState() => _RestaurantProfileState();
}

class _RestaurantProfileState extends State<RestaurantProfile> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _deliveryFeeController;
  late Set<RestaurantTag> _selectedTags;

  late bool _isOpen;
  late bool _hasOffer;
  bool _isInitialLoading = true;
  String? _loadError;

  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _nameErrorText;
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
    _isOpen = false;
    _hasOffer = false;
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
          : 'Restaurant location selected';
      _isOpen = restaurant.isOpen;
      _hasOffer = restaurant.hasOffer;

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

  Future<void> _signOut() async {
    final shouldSignOut = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
    );

    if (shouldSignOut != true) return;

    try {
      await AuthService().signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const StartScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
        ),
      );
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

  Future<void> _pickLocation() async {
    final existingLocation = _restaurantLocation;
    final result = await Navigator.push<CustomerAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          existing: existingLocation == null
              ? null
              : CustomerAddress(
                  id: 'restaurant_location',
                  label: '',
                  fullAddress: _locationPreview ?? '',
                  buildingDetails: '',
                  location: existingLocation,
                  isDefault: false,
                ),
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
      _restaurantLocation = result.location;
      _locationPreview = result.fullAddress;
      _locationErrorText = null;
    });
  }

  Future<void> _saveProfile() async {
    final nameError = Validators.validateRestaurantName(_nameController.text);
    if (nameError != null || _restaurantLocation == null) {
      setState(() {
        _nameErrorText = nameError;
        _locationErrorText = _restaurantLocation == null
            ? 'Please choose restaurant location on the map.'
            : null;
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deliveryFee =
          double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

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
        'isOpen': _isOpen,
        'hasOffer': _hasOffer,
        'imageUrl': uploadedImageUrl ?? _imageUrl ?? '',
      });

      if (!mounted) return;

      setState(() {
        _imageUrl = uploadedImageUrl;
        _selectedImageFile = null;
        _nameErrorText = null;
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
        SnackBar(
          content: Text('Failed to update profile: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggleOpen(bool value) {
    setState(() => _isOpen = value);
  }

  void _toggleOffer(bool value) {
    setState(() => _hasOffer = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Text(_loadError!),
        ),
      );
    }
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                          errorBuilder: (_, _, _) => _imagePlaceholder(scheme),
                        )
                      : _imagePlaceholder(scheme),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploadingImage ? null : _pickImage,
                  icon: const Icon(Icons.upload),
                  label: Text(
                    _isUploadingImage ? 'Uploading...' : 'Upload Image',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(widget.restaurant.email),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Restaurant ID'),
            subtitle: Text(widget.restaurant.id),
          ),
          const SizedBox(height: 12),
          _ProfileTextField(
            controller: _nameController,
            label: 'Restaurant Name',
            icon: Icons.storefront_outlined,
            errorText: _nameErrorText,
          ),
          const SizedBox(height: 12),

          _ProfileTextField(
            controller: _phoneController,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          _ProfileTextField(
            controller: _deliveryFeeController,
            label: 'Delivery Fee (SAR)',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text(
                'Restaurant Categories',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _selectedTags.isEmpty
                    ? 'None selected'
                    : _selectedTags.map((t) => t.label).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
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
          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: Icon(
              _restaurantLocation != null
                  ? Icons.location_on
                  : Icons.map_outlined,
              color: _restaurantLocation != null ? Colors.green : null,
            ),
            label: Text(
              _restaurantLocation != null
                  ? 'Location Selected'
                  : 'Choose Location on Map',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _restaurantLocation != null
                  ? Colors.green
                  : null,
            ),
          ),
          if (_restaurantLocation != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Restaurant location'),
                subtitle: Text(
                  _locationPreview ?? 'Restaurant location selected',
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
          if (_locationErrorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _locationErrorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _isOpen,
                  onChanged: _toggleOpen,
                  title: const Text('Restaurant Open'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _hasOffer,
                  onChanged: _toggleOffer,
                  title: const Text('Has Active Offer'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (_isSaving || _isUploadingImage) ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
          SizedBox(
            height: 50,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportScreen(
                      userId: widget.restaurant.id,
                      userRole: 'restaurant',
                      userName: widget.restaurant.name,
                      userEmail: widget.restaurant.email,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Support'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme scheme) {
    return Container(
      width: 120,
      height: 120,
      color: scheme.surfaceContainerHighest,
      child: const Icon(Icons.image, size: 40),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.errorText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? errorText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
