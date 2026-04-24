import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_delivery_platform/models/restaurant.dart';

import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';

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
  late final TextEditingController _typeController;
  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _tagsController;

  late bool _isOpen;
  late bool _hasOffer;

  bool _isSaving = false;
  bool _isUploadingImage = false;

  String? _imageUrl;
  File? _selectedImageFile;

  final ImagePicker _picker = ImagePicker();

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.restaurant.name);
    _phoneController = TextEditingController(text: widget.restaurant.phone);
    _typeController = TextEditingController(text: widget.restaurant.type);
    _deliveryFeeController = TextEditingController(
      text: widget.restaurant.deliveryFee.toStringAsFixed(0),
    );
    _tagsController = TextEditingController(
      text: widget.restaurant.tags.join(', '),
    );

    _isOpen = widget.restaurant.isOpen;
    _hasOffer = widget.restaurant.hasOffer;
    _imageUrl = widget.restaurant.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _typeController.dispose();
    _deliveryFeeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
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

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final deliveryFee =
          double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final uploadedImageUrl = await _uploadImageIfNeeded();
      if (!mounted) return;

      if (_selectedImageFile != null && uploadedImageUrl == null) {
        setState(() => _isSaving = false);
        return;
      }

      await _usersCollection.doc(widget.restaurant.id).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'type': _typeController.text.trim(),
        'deliveryFee': deliveryFee,
        'tags': tags,
        'isOpen': _isOpen,
        'hasOffer': _hasOffer,
        'imageUrl': uploadedImageUrl ?? _imageUrl ?? '',
      });

      setState(() {
        _imageUrl = uploadedImageUrl;
        _selectedImageFile = null;
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

  //Todo update in database
  Future<void> _toggleOpen(bool value) async {
    setState(() => _isOpen = value);

    try {
      await _usersCollection.doc(widget.restaurant.id).update({
        'isOpen': value,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOpen = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _toggleOffer(bool value) async {
    setState(() => _hasOffer = value);

    try {
      await _usersCollection.doc(widget.restaurant.id).update({
        'hasOffer': value,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasOffer = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update offer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                          errorBuilder: (_, __, ___) =>
                              _imagePlaceholder(scheme),
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
          const SizedBox(height: 12),
          _ProfileTextField(
            controller: _nameController,
            label: 'Restaurant Name',
            icon: Icons.storefront_outlined,
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
            controller: _typeController,
            label: 'Type',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),

          _ProfileTextField(
            controller: _deliveryFeeController,
            label: 'Delivery Fee (SAR)',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          _ProfileTextField(
            controller: _tagsController,
            label: 'Tags (comma separated)',
            icon: Icons.sell_outlined,
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
