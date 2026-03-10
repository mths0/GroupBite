import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/pages/otp_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';
import 'package:food_delivery_platform/utils/validators.dart';
import 'package:geolocator/geolocator.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String? nameErrorText;
  String? phoneErrorText;
  String? emailErrorText;
  String? _locationError;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  GeoPoint? _currentGeoPoint;

  String? errorText;
  bool isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void validateData() async {
    setState(() {
      nameErrorText = null;
      phoneErrorText = null;
      emailErrorText = null;
    });

    final nameError = Validators.validateName(_nameCtrl.text);
    final phoneError = Validators.validatePhone(_phoneCtrl.text);
    final emailError = Validators.validateEmail(_emailCtrl.text);

    if (nameError != null || phoneError != null || emailError != null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        emailErrorText = emailError;
      });
      return;
    }

    // on correct input => send OTP
    _submit();
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

    final phone = _phoneCtrl.text.trim(); // نخزن بدون +966 (مثل login_screen)

    try {
      // منع تكرار الحساب
      final existingUser = await db.getUserByPhone(phone);
      if (existingUser != null) {
        setState(() {
          isLoading = false;
          errorText = "Account already exists. Please login.";
        });
        return;
      }

      // Generate user id (سيتم حفظه بعد نجاح OTP داخل OtpScreen)
      final id = IdGenerator.generateUserId(UserRole.customer);

      final customer = Customer(
        id: id,
        phone: phone,
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        location: _currentGeoPoint,
        createdAt: DateTime.now().toIso8601String(),
      );

      final authService = AuthService();
      // Send OTP
      authService.sendOtp(
        phone: '+966${customer.phone}',

        onCodeSent: (verificationId) {
          setState(() => isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                user: customer,
                purpose: OtpPurpose.register,
                verificationId: verificationId,
              ),
            ),
          );
        },

        onAutoVerified: (userCredential) {
          // Android only (optional)
          // You can directly complete registration here if you want
        },

        onError: (error) {
          setState(() {
            phoneErrorText = error;
            isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        errorText = e.toString();
      });
    }
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
                const SizedBox(height: 12),

                if (errorText != null) ...[
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],

                // PHONE (9 digits + counter)
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

                // EMAIL
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    hintText: "customer@email.com",
                    prefixIcon: Icon(Icons.email),
                    errorText: emailErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                // FULL NAME
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Full name",
                    hintText: "Mohannad Alshahrani",
                    prefixIcon: Icon(Icons.person_outline),
                    errorText: nameErrorText,
                  ),
                ),
                const SizedBox(height: 12),

                // LOCATION
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
                        : const Text("Continue (Send OTP)"),
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
