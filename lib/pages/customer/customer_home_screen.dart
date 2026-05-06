import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/join_group_order_screen.dart';
import 'package:food_delivery_platform/pages/customer/restaurant_menu_page.dart';
import 'package:food_delivery_platform/models/restaurant_tag.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.customer});
  final Customer customer;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  GeoPoint? _deliveryLocation;
  bool _isLoadingAddress = true;
  String? _addressLabel;

  RestaurantTag? _selectedTag;
  String _selectedSort = "Nearest";

  final List<String> _sortOptions = const [
    "Nearest",
    "Delivery Fee",
    "Rating",
    "Name",
  ];
  double _distanceFromCustomer(Restaurant restaurant) {
    final customerLocation = _deliveryLocation;
    final restaurantLocation = restaurant.location;

    if (customerLocation == null || restaurantLocation == null) {
      return double.infinity;
    }

    final latDiff = customerLocation.latitude - restaurantLocation.latitude;
    final lngDiff = customerLocation.longitude - restaurantLocation.longitude;

    return (latDiff * latDiff) + (lngDiff * lngDiff);
  }

  String _distanceLabel(Restaurant restaurant) {
    final customerLocation = _deliveryLocation;
    final restaurantLocation = restaurant.location;

    if (customerLocation == null || restaurantLocation == null) {
      return '';
    }

    const kmPerLatDegree = 111.0;

    final latDiff = customerLocation.latitude - restaurantLocation.latitude;
    final lngDiff = customerLocation.longitude - restaurantLocation.longitude;

    final distanceKm =
        sqrt((latDiff * latDiff) + (lngDiff * lngDiff)) * kmPerLatDegree;

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  Future<void> _loadDeliveryLocation() async {
    setState(() {
      _isLoadingAddress = true;
      _addressLabel = null;
    });

    try {
      final defaultAddress = await DatabaseService().getDefaultCustomerAddress(
        widget.customer.id,
      );

      if (!mounted) return;

      setState(() {
        _deliveryLocation =
            defaultAddress?.location ?? widget.customer.location;
        _isLoadingAddress = false;

        if (defaultAddress != null) {
          _addressLabel = defaultAddress.label;
        } else if (widget.customer.location != null) {
          _addressLabel = 'your saved location';
        } else {
          _addressLabel = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deliveryLocation = widget.customer.location;
        _isLoadingAddress = false;
        _addressLabel = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDeliveryLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildSearchBar(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RestaurantTag?>(
                  initialValue: _selectedTag,
                  menuMaxHeight: 300,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fastfood_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<RestaurantTag?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...RestaurantTag.values.map((tag) {
                      return DropdownMenuItem<RestaurantTag?>(
                        value: tag,
                        child: Text(
                          tag.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTag = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSort,
                  menuMaxHeight: 300,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort),
                  ),
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(
                        option,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedSort = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 12, height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JoinGroupOrderScreen(
                    customer: widget.customer,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.group),
            label: const Text('Join Group Order'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _addressLabel == null
                      ? 'Restaurants Near You'
                      : 'Restaurants Near $_addressLabel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoadingAddress ? null : _loadDeliveryLocation,
                icon: _isLoadingAddress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_outlined),
                tooltip: 'Refresh delivery address',
              ),
            ],
          ),

          const SizedBox(height: 12),
          StreamBuilder<List<Restaurant>>(
            stream: DatabaseService().getRestaurants(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text("No Data found"),
                );
              }

              final filteredRestaurants = snapshot.data!.where((r) {
                final query = _searchController.text.toLowerCase();

                final nameMatch = r.name.toLowerCase().contains(query);
                final tagMatch = r.tags.any(
                  (tag) => tag.label.toLowerCase().contains(query),
                );

                final searchMatch = query.isEmpty || nameMatch || tagMatch;
                final categoryMatch =
                    _selectedTag == null || r.tags.contains(_selectedTag);

                return searchMatch && categoryMatch;
              }).toList();
              filteredRestaurants.sort((a, b) {
                // Open restaurants always come first.
                if (a.isOpen != b.isOpen) {
                  return a.isOpen ? -1 : 1;
                }

                switch (_selectedSort) {
                  case "Delivery Fee":
                    return a.deliveryFee.compareTo(b.deliveryFee);

                  case "Rating":
                    return b.rating.compareTo(a.rating);

                  case "Name":
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());

                  case "Nearest":
                  default:
                    final aDistance = _distanceFromCustomer(a);
                    final bDistance = _distanceFromCustomer(b);
                    return aDistance.compareTo(bDistance);
                }
              });

              if (filteredRestaurants.isEmpty) {
                return Center(
                  child: Text("No restaurants match your search."),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRestaurants.length,
                itemBuilder: (context, index) {
                  return buildRestaurantCard(
                    filteredRestaurants[index],
                    scheme,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search for restaurants or food...',
      ),
    );
  }

  Widget buildRestaurantCard(Restaurant restaurant, ColorScheme scheme) {
    final distanceLabel = _distanceLabel(restaurant);
    final isClosed = !restaurant.isOpen;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: restaurant.isOpen
          ? () {
              final cart = CartScope.of(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScope(
                    notifier: cart,
                    child: RestaurantMenuPage(
                      restaurant: restaurant,
                      customer: widget.customer,
                    ),
                  ),
                ),
              );
            }
          : null,
      child: Opacity(
        opacity: isClosed ? 0.55 : 1.0,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      restaurant.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 160,
                        color: scheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Row(
                      children: [
                        if (restaurant.hasOffer)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Offer',
                              style: TextStyle(color: scheme.onSecondary),
                            ),
                          ),
                        if (restaurant.hasOffer) const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: restaurant.isOpen
                                ? Colors.green
                                : scheme.outline,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            restaurant.isOpen ? 'Open' : 'Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(restaurant.rating.toStringAsFixed(1)),
                        const SizedBox(width: 12),

                        if (distanceLabel.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(distanceLabel),
                          const SizedBox(width: 12),
                        ],

                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text(_estimateDeliveryTime(restaurant)),

                        const SizedBox(width: 12),

                        const Icon(Icons.attach_money, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.deliveryFee == 0
                              ? 'Free'
                              : '${restaurant.deliveryFee.toStringAsFixed(0)} SAR',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: restaurant.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(tag.label),
                            ),
                          )
                          .toList(),
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

  String _estimateDeliveryTime(Restaurant restaurant) {
    //Todo : add min and max delivery time in restaurant model and calculate based on that and distance from customer
    if (!restaurant.isOpen) {
      return 'Unavailable';
    }

    if (restaurant.deliveryFee == 0) {
      return '20-25 min';
    }

    if (restaurant.deliveryFee <= 10) {
      return '25-30 min';
    }

    return '30-40 min';
  }
}
