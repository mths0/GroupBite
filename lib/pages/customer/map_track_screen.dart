import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Location _locationController = Location();

  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;

  //TODO For demo purposes, we use static locations for customer and restaurant.
  static const LatLng _customerLocation = LatLng(
    24.76860991323255,
    46.661047413133964,
  ); // (customer)
  static const LatLng _restaurantPosition = LatLng(
    24.7136,
    46.6753,
  ); // (restaurant)

  LatLng? _driverLocation;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Order"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            //TODO: make dynamic based on order info
            child: Center(child: Text("Order #123")),
          ),
        ],
      ),
      body: Column(
        children: [
          // GOOGLE MAP
          Expanded(
            child: GoogleMap(
              zoomControlsEnabled: false,
              initialCameraPosition: const CameraPosition(
                target: _customerLocation,
                zoom: 12,
              ),
              markers: {
                if (_restaurantIcon != null)
                  Marker(
                    markerId: const MarkerId("_restaurantLocation"),
                    position: _restaurantPosition,
                    icon: _restaurantIcon!,
                  ),
                if (_customerIcon != null)
                  Marker(
                    markerId: const MarkerId("_customerLocation"),
                    position: _customerLocation,
                    icon: _customerIcon!,
                  ),
                if (_driverLocation != null && _driverIcon != null)
                  Marker(
                    markerId: const MarkerId("_driverLocation"),
                    position: _driverLocation!,
                    icon: _driverIcon!,
                  ),
              },
            ),
          ),

          // DRIVER CARD
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange,
                        child: Text(
                          "JD",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            //TODO: make dynamic based on driver information
                            Text(
                              "John Doe",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text("Delivery Partner · 4.9 ⭐"),
                          ],
                        ),
                      ),
                      _IconButton(
                        icon: Icons.phone,
                        color: Colors.green,
                        //TODO: implement call functionality
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _IconButton(
                        icon: Icons.chat,
                        color: Colors.blue,
                        //TODO: implement chat functionality
                        onTap: () {},
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

//TODO: extract to separate file
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
