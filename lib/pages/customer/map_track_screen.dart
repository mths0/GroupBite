import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/driver.dart';
import 'package:yjeek/models/order.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Widget _buildDriverTracking(Order liveOrder) {
    return StreamBuilder<Driver?>(
      stream: DatabaseService().streamDriverById(liveOrder.driverId!),
      builder: (context, driverSnapshot) {
        final driver = driverSnapshot.data;

        LatLng? liveDriverLocation;
        if (driver?.location != null) {
          liveDriverLocation = LatLng(
            driver!.location!.latitude,
            driver.location!.longitude,
          );
        }

        final initialTarget = _customerLocationFromOrder(liveOrder);
        final topInset = MediaQuery.of(context).padding.top;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              GoogleMap(
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 12,
                ),
                markers: _buildMarkers(
                  liveOrder: liveOrder,
                  liveDriverLocation: liveDriverLocation,
                ),
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
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '966${cleanedPhone.substring(1)}';
    } else if (cleanedPhone.startsWith('5')) {
      cleanedPhone = '966$cleanedPhone';
    }

    final uri = Uri.parse('https://wa.me/$cleanedPhone');

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Widget _buildBottomCard({
    required Order liveOrder,
    required Driver? driver,
  }) {
    String title;
    String subtitle;

    switch (liveOrder.status) {
      case OrderStatus.assigned:
        title = "Driver heading to restaurant";
        subtitle = "The driver is on the way to pick up your order";
        break;
      case OrderStatus.pickedUp:
        title = "Driver heading to you";
        subtitle = "Your order has been picked up and is on the way";
        break;
      case OrderStatus.delivered:
        title = "Order delivered";
        subtitle = "Your order has been delivered";
        break;
      default:
        title = "Order update";
        subtitle = "Waiting for the next status update";
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.orange,
                      child: Text(
                        driver?.name.isNotEmpty == true
                            ? driver!.name[0].toUpperCase()
                            : "D",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver?.name ?? "Driver",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(subtitle),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: driver == null
                            ? null
                            : () => _openWhatsApp(driver.phone),
                        icon: const Icon(Icons.chat),
                        label: const Text("WhatsApp"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: driver == null
                            ? null
                            : () => _callDriver('+966${driver.phone}'),
                        icon: const Icon(Icons.call),
                        label: const Text("Call"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LatLng _customerLocationFromOrder(Order order) {
    return LatLng(
      order.customerLocation.latitude,
      order.customerLocation.longitude,
    );
  }

  LatLng _restaurantLocationFromOrder(Order order) {
    return LatLng(
      order.restaurantLocation.latitude,
      order.restaurantLocation.longitude,
    );
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

  // Set<Polyline> _buildPolylines({
  //   required Order liveOrder,
  //   required LatLng? liveDriverLocation,
  // }) {
  //   if (liveDriverLocation == null) return {};

  //   LatLng destination;

  //   if (liveOrder.status == OrderStatus.assigned) {
  //     destination = _restaurantLocationFromOrder(liveOrder);
  //   } else if (liveOrder.status == OrderStatus.pickedUp) {
  //     destination = _customerLocationFromOrder(liveOrder);
  //   } else {
  //     return {};
  //   }

  //   return {
  //     Polyline(
  //       polylineId: const PolylineId("driver_route"),
  //       points: [
  //         liveDriverLocation,
  //         destination,
  //       ],
  //       width: 5,
  //       color: Colors.blue,
  //     ),
  //   };
  // }

  Set<Marker> _buildMarkers({
    required Order liveOrder,
    required LatLng? liveDriverLocation,
  }) {
    final markers = <Marker>{};

    final restaurantLocation = _restaurantLocationFromOrder(liveOrder);
    final customerLocation = _customerLocationFromOrder(liveOrder);

    if (_restaurantIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("restaurant"),
          position: restaurantLocation,
          icon: _restaurantIcon!,
          infoWindow: const InfoWindow(title: "Restaurant"),
        ),
      );
    }

    if (_customerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("customer"),
          position: customerLocation,
          icon: _customerIcon!,
          infoWindow: const InfoWindow(title: "Customer"),
        ),
      );
    }

    if (liveDriverLocation != null && _driverIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("driver"),
          position: liveDriverLocation,
          icon: _driverIcon!,
          infoWindow: const InfoWindow(title: "Driver"),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: DatabaseService().streamOrderById(widget.order.id),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final liveOrder = orderSnapshot.data;
        if (liveOrder == null) {
          return const Scaffold(
            body: Center(child: Text("Order not found")),
          );
        }

        if (liveOrder.driverId == null || liveOrder.driverId!.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Track Order"),
            ),
            body: const Center(
              child: Text("No driver assigned yet"),
            ),
          );
        }

        return _buildDriverTracking(liveOrder);
      },
    );
  }
}
