import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';
import 'package:food_delivery_platform/utils/validators.dart';
import 'package:geolocator/geolocator.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key, required this.email});
  final String email;

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String? nameErrorText;
  String? phoneErrorText;
  String? _locationError;
  String? errorText;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  GeoPoint? _currentGeoPoint;
  bool isLoading = false;

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
      _locationError = null;
      errorText = null;
    });

    final nameError = Validators.validateName(_nameCtrl.text.trim());
    final phoneError = Validators.validatePhone(_phoneCtrl.text.trim());

    if (nameError != null || phoneError != null || _currentGeoPoint == null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        _locationError = _currentGeoPoint == null
            ? "Please capture your location."
            : null;
      });
      return;
    }

    await _submit();
  }

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationError = "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _locationError = "Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError =
              "Location permissions are permanently denied. Please enable them from settings.";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentGeoPoint = GeoPoint(position.latitude, position.longitude);
        _locationError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location captured successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = "Could not get location.");
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    final db = DatabaseService();
    final phone = _phoneCtrl.text.trim();

    try {
      final existingUser = await db.getUserByPhone(phone);
      if (existingUser != null) {
        setState(() {
          isLoading = false;
          phoneErrorText = "Phone number already exists. Please login.";
        });
        return;
      }

      final customer = Customer(
        id: IdGenerator.generateUserId(UserRole.customer),
        phone: phone,
        email: widget.email,
        name: _nameCtrl.text.trim(),
        location: _currentGeoPoint,
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.createUser(customer.toJson());

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
      appBar: AppBar(title: const Text("Customer Registration")),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Fill customer details",
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
                    labelText: "Full name",
                    hintText: "Cristiano Ronaldo",
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _getLocation,
                  icon: Icon(
                    _currentGeoPoint != null
                        ? Icons.location_on
                        : Icons.my_location,
                    color: _currentGeoPoint != null ? Colors.green : null,
                  ),
                  label: Text(
                    _currentGeoPoint != null
                        ? "Location Captured"
                        : "Get Current Location",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _currentGeoPoint != null
                        ? Colors.green
                        : null,
                  ),
                ),
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