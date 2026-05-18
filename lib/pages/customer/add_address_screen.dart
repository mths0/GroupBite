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
    this.title,
    this.showLabelField = true,
    this.showBuildingDetailsField = true,
    this.showDefaultToggle = true,
    this.saveButtonText = 'Save Address',
    this.onSubmit,
  });

  final CustomerAddress? existing;
  final String? title;
  final bool showLabelField;
  final bool showBuildingDetailsField;
  final bool showDefaultToggle;
  final String saveButtonText;

  /// Optional async callback that persists the address before the screen
  /// pops. When provided, the Save button waits for this to complete so
  /// the caller's UI is already in sync by the time we return.
  final Future<void> Function(CustomerAddress)? onSubmit;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _detailsController;
  bool _isSaving = false;

  Future<void> _openFullScreenMap() async {
    final initialTarget = _selectedLatLng ?? _initialRiyadh;
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _LocationPickerScreen(
              initialTarget: initialTarget,
              initialSelection: _selectedLatLng,
            ),
      ),
    );
    if (picked == null || !mounted) return;
    await _onMapTap(picked);
  }


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
      _resolvedAddress = widget.existing!.fullAddress.trim().isEmpty
          ? 'Selected location'
          : widget.existing!.fullAddress;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _detailsController.dispose();
    super.dispose();
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

  Future<void> _save() async {
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
      label: widget.showLabelField ? _labelController.text.trim() : '',
      fullAddress: _resolvedAddress.trim().isEmpty
          ? 'Selected location'
          : _resolvedAddress,
      buildingDetails: widget.showBuildingDetailsField
          ? _detailsController.text.trim()
          : '',
      location: GeoPoint(
        _selectedLatLng!.latitude,
        _selectedLatLng!.longitude,
      ),
      isDefault: widget.showDefaultToggle ? _isDefault : false,
    );

    final onSubmit = widget.onSubmit;
    if (onSubmit != null) {
      setState(() => _isSaving = true);
      try {
        await onSubmit(address);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
        return;
      }
      if (!mounted) return;
    }

    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _selectedLatLng ?? _initialRiyadh;

    final scheme = Theme
        .of(context)
        .colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.existing == null ? 'Add Address' : 'Edit Address'),
          style: Theme
              .of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _MapPreviewCard(
                  initialTarget: initialTarget,
                  selected: _selectedLatLng,
                  onTap: _openFullScreenMap,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showLabelField) ...[
                        _FieldLabel(text: 'Label'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _labelController,
                          decoration: const InputDecoration(
                            hintText: 'Home / Work / University',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (widget.showBuildingDetailsField) ...[
                        _FieldLabel(text: 'Home number / floor / apartment'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _detailsController,
                          decoration: const InputDecoration(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _FieldLabel(text: 'Address'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          border: Border.all(color: scheme.outlineVariant),
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
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    if (widget.showDefaultToggle) ...[
                      _DefaultToggleButton(
                        active: _isDefault,
                        onTap: () =>
                            setState(() => _isDefault = !_isDefault),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            widget.saveButtonText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({
    required this.initialTarget,
    required this.selected,
    required this.onTap,
  });

  final LatLng initialTarget;
  final LatLng? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            children: [
              AbsorbPointer(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: selected ?? initialTarget,
                    zoom: 14,
                  ),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                  markers: selected == null
                      ? {}
                      : {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: selected!,
                    ),
                  },
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Show more of the map',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _LocationPickerScreen extends StatefulWidget {
  const _LocationPickerScreen({
    required this.initialTarget,
    required this.initialSelection,
  });

  final LatLng initialTarget;
  final LatLng? initialSelection;

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  GoogleMapController? _controller;
  late LatLng? _selected;
  final loc.Location _locationService = loc.Location();
  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);
    try {
      var enabled = await _locationService.serviceEnabled();
      if (!enabled) {
        enabled = await _locationService.requestService();
        if (!enabled) return;
      }
      var perm = await _locationService.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await _locationService.requestPermission();
        if (perm != loc.PermissionStatus.granted) return;
      }
      final current = await _locationService.getLocation();
      if (current.latitude == null || current.longitude == null) return;
      final latLng = LatLng(current.latitude!, current.longitude!);
      if (!mounted) return;
      setState(() => _selected = latLng);
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 16)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    final topInset = MediaQuery
        .of(context)
        .padding
        .top;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selected ?? widget.initialTarget,
              zoom: 14,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
            },
            onTap: (pos) => setState(() => _selected = pos),
            markers: _selected == null
                ? {}
                : {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selected!,
              ),
            },
          ),
          Positioned(
            top: topInset + 8,
            left: 16,
            child: Material(
              color: Colors.white.withValues(alpha: 0.95),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.maybePop(context),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back, color: Colors.black87),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: topInset + 8,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: scheme.primary,
              onPressed:
              _isGettingCurrentLocation ? null : _goToCurrentLocation,
              child: _isGettingCurrentLocation
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Confirm Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DefaultToggleButton extends StatelessWidget {
  const _DefaultToggleButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Material(
      color: active ? scheme.primary : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: active ? 'Default address' : 'Set as default',
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              active ? Icons.star_rounded : Icons.star_border_rounded,
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
