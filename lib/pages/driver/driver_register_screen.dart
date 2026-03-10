import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'package:food_delivery_platform/components/loading_indicator.dart';
import 'package:food_delivery_platform/utils/validators.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/pages/otp_screen.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final nationalIdController = TextEditingController();
  GeoPoint? currentPosition;
  String? nameErrorText;
  String? phoneErrorText;
  String? nationalIdErrorText;
  bool isLoading = false;
  String? locationError;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

// Todo refactor location fetching to a separate service and use it in both restaurant and driver registration screens
  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => locationError = "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => locationError = "Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationError =
              "Location permissions are permanently denied. Please enable them from settings.";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        currentPosition = GeoPoint(position.latitude, position.longitude);
        locationError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location captured successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => locationError = "Could not get location.");
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void validateData() async {
    setState(() {
      nameErrorText = null;
      phoneErrorText = null;
      nationalIdErrorText = null;
      locationError = null;
    });

    final nameError = Validators.validateName(nameController.text);
    final phoneError = Validators.validatePhone(phoneController.text);
    final nationalIdError = Validators.validateNationalId(
      nationalIdController.text,
    );

    if (nameError != null ||
        phoneError != null ||
        nationalIdError != null ||
        currentPosition == null) {
      setState(() {
        nameErrorText = nameError;
        phoneErrorText = phoneError;
        nationalIdErrorText = nationalIdError;
        locationError = currentPosition == null
            ? "Please capture your location before continuing."
            : null;
      });
      return;
    }

    // on correct input
    // mock
    // print('Driver data is valid');
    final driver = Driver(
      id: IdGenerator.generateUserId(UserRole.driver),
      name: nameController.text,
      phone: phoneController.text,
      nationalId: nationalIdController.text,
      createdAt: DateTime.now().toIso8601String(),
      location: currentPosition,
    );
    setState(() {
      isLoading = true;
    });

    // check if user exists
    final db = DatabaseService();
    final existingDriver = await db.getUserByPhone(driver.phone);
    if (!mounted) return;
    if (existingDriver != null) {
      setState(() {
        phoneErrorText = "Account already exists. Please Login.";
        isLoading = false;
      });
      return;
    }

    final authService = AuthService();

    await authService.sendOtp(
      phone: '+966${driver.phone}',

      onCodeSent: (verificationId) {
        setState(() => isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              user: driver,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Text("Driver register screen"),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  hintText: '5X XXX XXXX',
                  prefixIcon: const Icon(Icons.phone),
                  errorText: phoneErrorText,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: nationalIdController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: "National ID",
                  errorText: nationalIdErrorText,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: nameController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  hintText: 'mohaned alshahrani',
                  errorText: nameErrorText,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _getLocation,
                icon: Icon(
                  currentPosition != null
                      ? Icons.location_on
                      : Icons.my_location,
                  color: currentPosition != null ? Colors.green : null,
                ),
                label: Text(
                  currentPosition != null
                      ? "Location Captured"
                      : "Get Current Location",
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: currentPosition != null
                      ? Colors.green
                      : null,
                ),
              ),
              if (locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    locationError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: isLoading
                    ? LoadingIndicator()
                    : ElevatedButton(
                        onPressed: validateData,
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16),
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
