import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yjeek/pages/start_screen.dart';
import 'package:geolocator/geolocator.dart';

import 'package:yjeek/utils/validators.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/utils/id_generator.dart';

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
  bool isCapturingLocation = false;

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
      isCapturingLocation = true;
      locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          locationError = "Location services are disabled.";
          isCapturingLocation = false;
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
          isCapturingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationError =
              "Location permissions are permanently denied. Please enable them from settings.";
          isCapturingLocation = false;
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
        isCapturingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location captured successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationError = "Could not get location.";
        isCapturingLocation = false;
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
      rating: 5,
      ratingCount: 0,
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
        MaterialPageRoute(builder: (_) => const StartScreen()),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = currentPosition != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driver Registration',
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text(
                'Tell us about you',
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
              if (generalErrorText != null) ...[
                Text(
                  generalErrorText!,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
              ],
              _FieldLabel('Phone number'),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
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
              _FieldLabel('National ID'),
              const SizedBox(height: 6),
              TextField(
                controller: nationalIdController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) {
                  if (nationalIdErrorText != null) {
                    setState(() => nationalIdErrorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: '10-digit national ID',
                  errorText: nationalIdErrorText,
                ),
              ),
              const SizedBox(height: 18),
              _FieldLabel('Full name'),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (nameErrorText != null) {
                    setState(() => nameErrorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Cristiano Ronaldo',
                  errorText: nameErrorText,
                ),
              ),
              const SizedBox(height: 22),
              _FieldLabel('Current location'),
              const SizedBox(height: 6),
              if (hasLocation)
                Material(
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: isCapturingLocation ? null : _getLocation,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          Icon(Icons.my_location, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location captured',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${currentPosition!.latitude.toStringAsFixed(5)}, '
                                  '${currentPosition!.longitude.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.refresh,
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
                    onPressed: isCapturingLocation ? null : _getLocation,
                    icon: isCapturingLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurface,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(
                      isCapturingLocation
                          ? 'Capturing...'
                          : 'Get current location',
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
              if (locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    locationError!,
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
