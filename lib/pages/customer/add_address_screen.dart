import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:food_delivery_platform/models/customer_address.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({
    super.key,
    this.existing,
  });

  final CustomerAddress? existing;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _detailsController;
  final loc.Location _locationController = loc.Location();
  bool _isGettingCurrentLocation = false;

  GoogleMapController? _mapController;

  LatLng? _selectedLatLng;
  String _resolvedAddress = '';
  bool _isLoadingAddress = false;
  bool _isDefault = false;

  static const LatLng _initialRiyadh = LatLng(24.7136, 46.6753);

  @override
  void initState() {
    super.initState();

    _labelController = TextEditingController(
      text: widget.existing?.label ?? '',
    );
    _detailsController = TextEditingController(
      text: widget.existing?.buildingDetails ?? '',
    );
    _isDefault = widget.existing?.isDefault ?? false;

    if (widget.existing?.location != null) {
      _selectedLatLng = LatLng(
        widget.existing!.location!.latitude,
        widget.existing!.location!.longitude,
      );
      _resolvedAddress = widget.existing!.fullAddress;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _detailsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);

    try {
      bool serviceEnabled = await _locationController.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationController.requestService();
        if (!serviceEnabled) {
          setState(() => _isGettingCurrentLocation = false);
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await _locationController
          .hasPermission();

      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _locationController.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _isGettingCurrentLocation = false);
          return;
        }
      }

      final currentLocation = await _locationController.getLocation();

      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        setState(() => _isGettingCurrentLocation = false);
        return;
      }

      final latLng = LatLng(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      setState(() {
        _selectedLatLng = latLng;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16),
        ),
      );

      await _onMapTap(latLng);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingCurrentLocation = false);
      }
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedLatLng = position;
      _isLoadingAddress = true;
      _resolvedAddress = '';
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts =
            [
                  p.street,
                  p.subLocality,
                  p.locality,
                  p.administrativeArea,
                  p.country,
                ]
                .where((e) => e != null && e.trim().isNotEmpty)
                .cast<String>()
                .toList();

        setState(() {
          _resolvedAddress = parts.join(', ');
        });
      } else {
        setState(() {
          _resolvedAddress = 'Selected location';
        });
      }
    } catch (e) {
      setState(() {
        _resolvedAddress = 'Could not resolve address';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a location on the map')),
      );
      return;
    }

    final address = CustomerAddress(
      id:
          widget.existing?.id ??
          FirebaseFirestore.instance.collection('tmp').doc().id,
      label: _labelController.text.trim(),
      fullAddress: _resolvedAddress,
      buildingDetails: _detailsController.text.trim(),
      location: GeoPoint(
        _selectedLatLng!.latitude,
        _selectedLatLng!.longitude,
      ),
      isDefault: _isDefault,
    );

    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _selectedLatLng ?? _initialRiyadh;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Address' : 'Edit Address'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (widget.existing == null && _selectedLatLng == null) {
                        _goToCurrentLocation();
                      }
                    },
                    onTap: _onMapTap,
                    markers: _selectedLatLng == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('selected_location'),
                              position: _selectedLatLng!,
                            ),
                          },
                  ),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: FloatingActionButton.small(
                      onPressed: _isGettingCurrentLocation
                          ? null
                          : _goToCurrentLocation,
                      child: _isGettingCurrentLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'Home / Work / University',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailsController,
                    decoration: const InputDecoration(
                      labelText: 'Home number / floor / apartment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoadingAddress
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Resolving address...'),
                            ],
                          )
                        : Text(
                            _resolvedAddress.isEmpty
                                ? 'Tap on the map to choose location'
                                : _resolvedAddress,
                          ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    title: const Text('Set as default'),
                  ),
                  const SizedBox(height: 12),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Address'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
