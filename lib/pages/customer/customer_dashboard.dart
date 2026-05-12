import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/customer_address.dart';
import 'package:food_delivery_platform/pages/customer/address_widgets.dart';
import 'package:food_delivery_platform/pages/customer/customer_home_screen.dart';
import 'package:food_delivery_platform/pages/customer/customer_orders_screen.dart';
import 'package:food_delivery_platform/pages/customer/customer_profile_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key, required this.customer});
  final Customer customer;

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _navIndex = 0;
  final PageController _pageController = PageController();

  GeoPoint? _deliveryLocation;
  String? _addressLabel;
  String? _addressFullText;
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });
    try {
      final defaultAddress = await DatabaseService().getDefaultCustomerAddress(
        widget.customer.id,
      );
      if (!mounted) return;
      setState(() {
        _deliveryLocation =
            defaultAddress?.location ?? widget.customer.location;
        if (defaultAddress != null) {
          _addressLabel = defaultAddress.label;
          _addressFullText = defaultAddress.fullAddress;
        } else if (widget.customer.location != null) {
          _addressLabel = 'your saved location';
          _addressFullText = null;
        } else {
          _addressLabel = null;
          _addressFullText = null;
        }
        _isLoadingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deliveryLocation = widget.customer.location;
        _addressLabel = null;
        _addressFullText = null;
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _openSessionAddressPicker() async {
    final picked = await showModalBottomSheet<CustomerAddress>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddressPickerSheet(
        customerId: widget.customer.id,
        title: 'Deliver to',
        subtitle:
            'Pick an address for this session. Your default stays the same.',
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _deliveryLocation = picked.location;
      _addressLabel = picked.label;
      _addressFullText = picked.fullAddress;
    });
  }

  void _goToPage(int index) {
    setState(() {
      _navIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      CustomerHomeScreen(
        customer: widget.customer,
        deliveryLocation: _deliveryLocation,
        addressLabel: _addressLabel,
        addressFullText: _addressFullText,
        isLoadingAddress: _isLoadingAddress,
        onPickAddress: _openSessionAddressPicker,
      ),
      CustomerOrdersScreen(customer: widget.customer),
      CustomerProfileScreen(
        customer: widget.customer,
        onDefaultAddressChanged: _loadDefaultAddress,
      ),
    ];

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome, ${widget.customer.name}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _navIndex = index),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _goToPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
