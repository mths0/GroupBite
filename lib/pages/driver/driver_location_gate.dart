import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/pages/driver/driver_dashboard.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationGate extends StatefulWidget {
  const DriverLocationGate({super.key, required this.driver});

  final Driver driver;

  @override
  State<DriverLocationGate> createState() => _DriverLocationGateState();
}

class _DriverLocationGateState extends State<DriverLocationGate>
    with WidgetsBindingObserver {
  bool _isChecking = true;
  String? _message;
  firestore.GeoPoint? _sharedLocation;
  DriverStatus? _statusBeforeBlock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifyAndShareLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyAndShareLocation(requestPermission: false);
    }
  }

  Future<void> _verifyAndShareLocation({
    bool requestPermission = true,
  }) async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _blockAccess('Turn on Location Services to continue as driver.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        await _blockAccess(
          'Location permission is required to enter driver mode.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        await _blockAccess(
          'Location permission is permanently denied. Enable it from app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = firestore.GeoPoint(
        position.latitude,
        position.longitude,
      );

      await DatabaseService().updateDriverLocation(
        driverId: widget.driver.id,
        location: location,
      );

      final statusToRestore = _statusBeforeBlock;
      if (statusToRestore != null && statusToRestore != DriverStatus.offline) {
        widget.driver.updateStatus(statusToRestore);
        await DatabaseService().updateDriverStatus(
          widget.driver.id,
          statusToRestore,
        );
      }

      if (!mounted) return;
      setState(() {
        _sharedLocation = location;
        _statusBeforeBlock = null;
        _isChecking = false;
        _message = null;
      });
    } catch (e) {
      await _blockAccess(
        'Could not share your current location. Please try again.',
      );
    }
  }

  Future<void> _blockAccess(String message) async {
    _statusBeforeBlock ??= widget.driver.status;
    widget.driver.updateStatus(DriverStatus.offline);

    try {
      await DatabaseService().updateDriverStatus(
        widget.driver.id,
        DriverStatus.offline,
      );
    } catch (_) {
      // The gate still blocks locally if the status write fails.
    }

    if (!mounted) return;
    setState(() {
      _sharedLocation = null;
      _isChecking = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sharedLocation = _sharedLocation;
    if (sharedLocation != null && !_isChecking) {
      return DriverDashboard(
        driver: widget.driver,
        initialLocation: sharedLocation,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location Required',
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Share your live location',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _message ??
                        'Checking location permission before opening driver mode.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isChecking)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _verifyAndShareLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: Geolocator.openLocationSettings,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text(
                          'Location Settings',
                          style: TextStyle(
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
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: Geolocator.openAppSettings,
                        icon: const Icon(
                          Icons.app_settings_alt_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'App Settings',
                          style: TextStyle(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
