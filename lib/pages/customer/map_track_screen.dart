import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:food_delivery_platform/models/order.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Location _locationController = Location();

  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;

  LatLng? _driverLocation;

  LatLng get _customerLocation => LatLng(
    widget.order.customerLocation.latitude,
    widget.order.customerLocation.longitude,
  );

  LatLng get _restaurantLocation => LatLng(
    widget.order.restaurantLocation.latitude,
    widget.order.restaurantLocation.longitude,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    _restaurantIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/map_icons/restaurant.png",
    );
    _customerIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/map_icons/customer.png",
    );
    _driverIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/map_icons/driver.png",
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _locationController.onLocationChanged.listen((currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _driverLocation = LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
        });
      }
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_restaurantIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("restaurant"),
          position: _restaurantLocation,
          icon: _restaurantIcon!,
          infoWindow: const InfoWindow(title: "Restaurant"),
        ),
      );
    }

    if (_customerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("customer"),
          position: _customerLocation,
          icon: _customerIcon!,
          infoWindow: const InfoWindow(title: "Customer"),
        ),
      );
    }

    if (_driverLocation != null && _driverIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("driver"),
          position: _driverLocation!,
          icon: _driverIcon!,
          infoWindow: const InfoWindow(title: "Driver"),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _customerLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Order"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text("Order #${widget.order.id}")),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              zoomControlsEnabled: false,
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 12,
              ),
              markers: _buildMarkers(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange,
                        child: Text(
                          "DR",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Driver",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text("Live tracking"),
                          ],
                        ),
                      ),
                    ],
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
