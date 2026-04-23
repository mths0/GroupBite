import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:geolocator/geolocator.dart';

import 'package:food_delivery_platform/components/loading_indicator.dart';
import 'package:food_delivery_platform/utils/validators.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/utils/id_generator.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key, required this.email});

  final String email;

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
  String? locationError;
  String? generalErrorText;

  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          locationError = "Location services are disabled.";
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          locationError = "Location permission denied.";
          isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationError =
              "Location permissions are permanently denied. Please enable them from settings.";
          isLoading = false;
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
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location captured successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationError = "Could not get location.";
        isLoading = false;
      });
    }
  }

  Future<void> validateData() async {
    setState(() {
      nameErrorText = null;
      phoneErrorText = null;
      nationalIdErrorText = null;
      locationError = null;
      generalErrorText = null;
    });

    final nameError = Validators.validateName(nameController.text.trim());
    final phoneError = Validators.validatePhone(phoneController.text.trim());
    final nationalIdError = Validators.validateNationalId(
      nationalIdController.text.trim(),
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

    final driver = Driver(
      id: IdGenerator.generateUserId(UserRole.driver),
      name: nameController.text.trim(),
      email: widget.email,
      phone: phoneController.text.trim(),
      nationalId: nationalIdController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
      location: currentPosition,
      
      // add these only if they exist in your model
      // isVerified: false,
      // status: DriverStatus.available,
    );

    setState(() {
      isLoading = true;
    });

    try {
      final db = DatabaseService();

      final existingByPhone = await db.getUserByPhone(driver.phone);
      if (existingByPhone != null) {
        setState(() {
          phoneErrorText = "Phone number already registered.";
          isLoading = false;
        });
        return;
      }

      /*TODO : we should also check for national ID duplicates,
       but currently we don't have a method for that in DatabaseService.
       We can add getDriverByNationalId and use it here.
      */

      // final existingByNationalId = await db.getDriverByNationalId(
      //   driver.nationalId,
      // );
      // if (existingByNationalId != null) {
      //   setState(() {
      //     nationalIdErrorText = "National ID already registered.";
      //     isLoading = false;
      //   });
      //   return;
      // }

      await db.createUser(driver.toJson());

      final authService = AuthService();
      await authService.sendMagicLink(widget.email);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Registration saved. A sign-in link was sent to ${widget.email}",
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(
    builder: (_) => const StartScreen(),
  ),
  (route) => false,
);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        generalErrorText = "Something went wrong. Please try again.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Registration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Text(
                "Register as Driver",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),

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
                keyboardType: TextInputType.number,
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
                  hintText: 'Cristiano Ronaldo',
                  errorText: nameErrorText,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: isLoading ? null : _getLocation,
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

              if (generalErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    generalErrorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: isLoading
                    ? const LoadingIndicator()
                    : ElevatedButton(
                        onPressed: validateData,
                        child: const Text(
                          'Register',
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
