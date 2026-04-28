import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/abstract_user.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/driver.dart';
import 'package:food_delivery_platform/models/order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverActiveOrderCard extends StatefulWidget {
  const DriverActiveOrderCard({
    super.key,
    required this.order,
    required this.driver,
    required this.onPickedUp,
    required this.onDelivered,
  });

  final Order order;
  final Driver driver;
  final Future<void> Function() onPickedUp;
  final Future<void> Function() onDelivered;

  @override
  State<DriverActiveOrderCard> createState() => _DriverActiveOrderCardState();
}

class _DriverActiveOrderCardState extends State<DriverActiveOrderCard> {
  Restaurant? _restaurant;
  Customer? _customer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseService();

    final restaurantUser = await db.getUserById(widget.order.restaurantId);
    final customerUser = await db.getUserById(widget.order.customerId);

    if (!mounted) return;

    setState(() {
      _restaurant = restaurantUser is Restaurant ? restaurantUser : null;
      _customer = customerUser is Customer ? customerUser : null;
      _isLoading = false;
    });
  }

  String _saudiPhone(String phone) => '+966$phone';

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

  Future<void> _openDirections({
    required double destinationLat,
    required double destinationLng,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isGoingToRestaurant = widget.order.status == OrderStatus.assigned;
    final isGoingToCustomer = widget.order.status == OrderStatus.pickedUp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Order #${widget.order.id}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Total: ${widget.order.totalPrice.toStringAsFixed(2)} SAR",
              ),
              const SizedBox(height: 16),

              if (isGoingToRestaurant) ...[
                const Text(
                  "Go to Restaurant",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _openDirections(
                    destinationLat: widget.order.restaurantLocation.latitude,
                    destinationLng: widget.order.restaurantLocation.longitude,
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text("Open Google Maps"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _restaurant == null
                      ? null
                      : () => _callPhone(_saudiPhone(_restaurant!.phone)),
                  icon: const Icon(Icons.call),
                  label: const Text("Call Restaurant"),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onPickedUp,
                  child: const Text("Picked Up"),
                ),
              ],

              if (isGoingToCustomer) ...[
                const Text(
                  "Go to Customer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _openDirections(
                    destinationLat: widget.order.customerLocation.latitude,
                    destinationLng: widget.order.customerLocation.longitude,
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text("Open Google Maps"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _customer == null
                      ? null
                      : () => _callPhone(_saudiPhone(_customer!.phone)),
                  icon: const Icon(Icons.call),
                  label: const Text("Call Customer"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _customer == null
                      ? null
                      : () => _openWhatsApp(_customer!.phone),
                  icon: const Icon(Icons.chat),
                  label: const Text("WhatsApp Customer"),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onDelivered,
                  child: const Text("Delivered"),
                ),
              ],

              if (!isGoingToRestaurant && !isGoingToCustomer)
                const Text("No active driver action for this order."),
            ],
          ),
        ),
      ),
    );
  }
}
