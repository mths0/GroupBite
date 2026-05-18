import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/customer_address.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/add_address_screen.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:yjeek/utils/id_generator.dart';
import 'package:yjeek/utils/validators.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text("Restaurant Registration")),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Fill restaurant details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),

                if (errorText != null) ...[
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
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
                    labelText: "Phone number",
                    hintText: "5XXXXXXXX",
                    prefixIcon: const Icon(Icons.phone),
                    errorText: phoneErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Restaurant name",
                    hintText: "Chapati & Karak",
                    prefixIcon: const Icon(Icons.storefront),
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  "Restaurant categories",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tagsErrorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: Icon(
                    _selectedLocation?.location != null
                        ? Icons.location_on
                        : Icons.map_outlined,
                    color: _selectedLocation?.location != null
                        ? Colors.green
                        : null,
                  ),
                  label: Text(
                    _selectedLocation?.location != null
                        ? "Location Selected"
                        : "Choose Location on Map",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _selectedLocation?.location != null
                        ? Colors.green
                        : null,
                  ),
                ),
                if (_selectedLocation?.location != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Restaurant location'),
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
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: validateData,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Register"),
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
