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
  String? _addressId;
  String? _addressLabel;
  String? _addressFullText;
  bool _isLoadingAddress = true;
  bool _hasAutoPromptedForAddress = false;

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
        if (defaultAddress != null) {
          _deliveryLocation = defaultAddress.location;
          _addressId = defaultAddress.id;
          _addressLabel = defaultAddress.label;
          _addressFullText = defaultAddress.fullAddress;
        } else {
          _deliveryLocation = null;
          _addressId = null;
          _addressLabel = null;
          _addressFullText = null;
        }
        _isLoadingAddress = false;
      });
      _maybeAutoPromptForAddress();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deliveryLocation = null;
        _addressId = null;
        _addressLabel = null;
        _addressFullText = null;
        _isLoadingAddress = false;
      });
      _maybeAutoPromptForAddress();
    }
  }

  void _maybeAutoPromptForAddress() {
    if (_hasAutoPromptedForAddress) return;
    if (_deliveryLocation != null) return;
    _hasAutoPromptedForAddress = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openSessionAddressPicker();
    });
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
        selectedAddressId: _addressId,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _deliveryLocation = picked.location;
      _addressId = picked.id;
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

    return Scaffold(
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
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
