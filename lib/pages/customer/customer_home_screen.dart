import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yjeek/cart/cart_scope.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/models/restaurant_tag.dart';
import 'package:yjeek/pages/customer/join_group_order_screen.dart';
import 'package:yjeek/pages/customer/restaurant_menu_page.dart';
import 'package:yjeek/themes/app_theme.dart';
import 'package:yjeek/utils/location_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    required this.customer,
    required this.deliveryLocation,
    required this.addressLabel,
    required this.addressFullText,
    required this.isLoadingAddress,
    required this.onPickAddress,
  });

  final Customer customer;
  final GeoPoint? deliveryLocation;
  final String? addressLabel;
  final String? addressFullText;
  final bool isLoadingAddress;
  final VoidCallback onPickAddress;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Restaurant>> _restaurantsStream = DatabaseService()
      .getRestaurants();

  GeoPoint? get _deliveryLocation => widget.deliveryLocation;

  RestaurantTag? _selectedTag;
  String _selectedSort = "Default";

  static const List<String> _sortOptions = [
    "Default",
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
    return LocationService.distanceInKm(
      from: restaurantLocation,
      to: customerLocation,
    );
  }

  String _distanceLabel(Restaurant restaurant) {
    if (_deliveryLocation == null || restaurant.location == null) {
      return '';
    }
    final km = LocationService.distanceInKm(
      from: restaurant.location!,
      to: _deliveryLocation!,
    );
    return '${km.toStringAsFixed(1)} km away';
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

    final hasDeliveryLocation = widget.deliveryLocation != null;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildHeader(theme, scheme),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: hasDeliveryLocation
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        _buildSearchBar(scheme),
                        const SizedBox(height: 12),
                        _buildJoinGroupOrderButton(),
                        const SizedBox(height: 20),
                        _buildCategoryChips(scheme),
                        const SizedBox(height: 12),
                        _buildSortBy(theme, scheme),
                        const SizedBox(height: 8),
                        _buildRestaurantList(scheme),
                      ],
                    )
                  : _buildNoAddressState(theme, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAddressState(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'You have to choose an address',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a delivery address to start browsing restaurants.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onPickAddress,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text(
                'Choose address',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    final hasAddress = widget.addressLabel?.isNotEmpty == true;
    final addressText = widget.isLoadingAddress
        ? 'Loading…'
        : (hasAddress ? widget.addressLabel! : 'Pick address');
    final subtitle = widget.addressFullText ?? '';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onPickAddress,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          addressText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!widget.isLoadingAddress &&
                            hasAddress &&
                            subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Yjeek',
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
        hintText: 'Search restaurants or cuisines...',
        fillColor: scheme.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildJoinGroupOrderButton() {
    return FilledButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JoinGroupOrderScreen(customer: widget.customer),
          ),
        );
      },
      icon: const Icon(Icons.groups_outlined, size: 20),
      label: const Text('Join Group Order'),
    );
  }

  Widget _buildCategoryChips(ColorScheme scheme) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RestaurantTag.values.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Builder(
            builder: (chipContext) {
              void selectAndScroll(VoidCallback select) {
                select();
                Scrollable.ensureVisible(
                  chipContext,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              }

              if (index == 0) {
                return _CategoryChip(
                  label: 'All',
                  selected: _selectedTag == null,
                  onTap: () => selectAndScroll(
                    () => setState(() => _selectedTag = null),
                  ),
                );
              }
              final tag = RestaurantTag.values[index - 1];
              return _CategoryChip(
                label: tag.label,
                selected: _selectedTag == tag,
                onTap: () => selectAndScroll(
                  () => setState(() => _selectedTag = tag),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSortBy(ThemeData theme, ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        initialValue: _selectedSort,
        onSelected: (value) => setState(() => _selectedSort = value),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => _sortOptions
            .map(
              (opt) => PopupMenuItem<String>(value: opt, child: Text(opt)),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort, size: 18, color: scheme.onSurface),
              const SizedBox(width: 6),
              Text(
                'Sort By: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _selectedSort,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: scheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantList(ColorScheme scheme) {
    return StreamBuilder<List<Restaurant>>(
      stream: _restaurantsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No restaurants found.')),
          );
        }

        final query = _searchController.text.toLowerCase();
        final filtered = snapshot.data!
            .where((r) {
              final nameMatch = r.name.toLowerCase().contains(query);
              final tagMatch = r.tags.any(
                (tag) => tag.label.toLowerCase().contains(query),
              );
              final searchMatch = query.isEmpty || nameMatch || tagMatch;
              final categoryMatch =
                  _selectedTag == null || r.tags.contains(_selectedTag);
              return searchMatch && categoryMatch;
            })
            .where(
              (r) => LocationService.isWithinDistanceKm(
                from: r.location,
                to: _deliveryLocation,
                maxDistanceKm: 10.0,
              ),
            )
            .toList();

        filtered.sort((a, b) {
          if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
          switch (_selectedSort) {
            case "Delivery Fee":
              return a.deliveryFee.compareTo(b.deliveryFee);
            case "Rating":
              return b.rating.compareTo(a.rating);
            case "Name":
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case "Nearest":
              return _distanceFromCustomer(a).compareTo(
                _distanceFromCustomer(b),
              );
            case "Default":
            default:
              return 0;
          }
        });

        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No restaurants match your search.')),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) =>
              _buildRestaurantCard(filtered[i], scheme),
        );
      },
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, ColorScheme scheme) {
    final brand = Theme.of(context).extension<BrandColors>()!;
    final isClosed = !restaurant.isOpen;
    final cuisine = restaurant.tags.take(2).map((t) => t.label).join('  •  ');
    final distance = _distanceLabel(restaurant);

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
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.network(
                    restaurant.imageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 170,
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  if (restaurant.hasOffer)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        label: 'Offer',
                        background: brand.offer,
                        foreground: brand.onOffer,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _Badge(
                      label: restaurant.isOpen ? 'Open' : 'Closed',
                      background: restaurant.isOpen
                          ? brand.openStatus
                          : scheme.outline,
                      foreground: restaurant.isOpen
                          ? brand.onOpenStatus
                          : scheme.surface,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cuisine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cuisine,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (distance.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          restaurant.deliveryFee == 0
                              ? 'Free Delivery'
                              : '${restaurant.deliveryFee.toStringAsFixed(2)} SAR Fee',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _RatingPill(
                          rating: restaurant.rating,
                          scheme: scheme,
                        ),
                      ],
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.scheme});

  final double rating;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: scheme.secondary, size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
