import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/cart/cart_controller.dart';
import 'package:food_delivery_platform/cart/cart_scope.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/cart_models.dart' as cart_models;
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/group_order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/checkout_screen.dart';
import 'package:food_delivery_platform/pages/customer/restaurant_menu_page.dart';
import 'package:food_delivery_platform/utils/tax.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GroupOrderSummaryScreen extends StatelessWidget {
  const GroupOrderSummaryScreen({
    super.key,
    required this.groupOrderId,
    required this.customer,
    required this.restaurant,
  });

  final String groupOrderId;
  final Customer customer;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<GroupOrder?>(
      stream: db.watchGroupOrder(groupOrderId),
      builder: (context, groupSnapshot) {
        final groupOrder = groupSnapshot.data;

        if (groupSnapshot.connectionState != ConnectionState.waiting &&
            (groupOrder == null ||
                groupOrder.status == GroupOrderStatus.cancelled)) {
          return _ErrorStateScreen(
            icon: Icons.cancel_outlined,
            title: 'Order Cancelled',
            message: 'This group order is no longer available.',
            onPop: () => Navigator.pop(context),
          );
        }

        if (groupOrder == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isHost = groupOrder.hostCustomerId == customer.id;

        return StreamBuilder<List<GroupOrderMember>>(
          stream: db.watchGroupMembers(groupOrderId),
          builder: (context, membersSnapshot) {
            final members = membersSnapshot.data ?? [];

            final isStillMember = members.any(
              (m) => m.customerId == customer.id,
            );
            if (membersSnapshot.hasData && !isStillMember) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You were removed from the group order.'),
                  ),
                );

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => CartScope(
                      notifier: CartController(),
                      child: RestaurantMenuPage(
                        restaurant: restaurant,
                        customer: customer,
                      ),
                    ),
                  ),
                  (route) => false,
                );
              });

              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return StreamBuilder<List<GroupOrderItem>>(
              stream: db.watchGroupItems(groupOrderId),
              builder: (context, itemsSnapshot) {
                final allItems = itemsSnapshot.data ?? [];

                // 1. Calculate Individual Base Shares
                final subtotal = allItems.fold<double>(
                  0,
                  (sum, item) => sum + item.lineTotal,
                );
                final tax = subtotal * kTaxRate;
                final deliveryFee = restaurant.deliveryFee;
                final grandTotal = subtotal + tax + deliveryFee;

                // Map to store base shares for each member ID
                final Map<String, Map<String, double>> memberDetails = {};
                for (final member in members) {
                  final mItems = allItems
                      .where((i) => i.memberId == member.customerId)
                      .toList();
                  final mSubtotal = mItems.fold<double>(
                    0,
                    (sum, i) => sum + i.lineTotal,
                  );
                  final mTax = mSubtotal * kTaxRate;

                  double mDeliveryShare = 0;
                  double mBaseShare = 0;

                  if (groupOrder.totalSplitStrategy == 'equal') {
                    mBaseShare =
                        grandTotal / (members.isEmpty ? 1 : members.length);
                    // For equal split, we just distribute the grand total
                  } else {
                    if (groupOrder.deliveryFeeSplit == 'equal') {
                      mDeliveryShare =
                          deliveryFee / (members.isEmpty ? 1 : members.length);
                    } else if (groupOrder.deliveryFeeSplit == 'proportional') {
                      mDeliveryShare = subtotal > 0
                          ? (mSubtotal / subtotal) * deliveryFee
                          : 0;
                    } else if (groupOrder.deliveryFeeSplit == 'host') {
                      mDeliveryShare =
                          member.customerId == groupOrder.hostCustomerId
                          ? deliveryFee
                          : 0;
                    }
                    mBaseShare = mSubtotal + mTax + mDeliveryShare;
                  }

                  memberDetails[member.customerId] = {
                    'subtotal': mSubtotal,
                    'tax': mTax,
                    'delivery': mDeliveryShare,
                    'baseShare': mBaseShare,
                  };
                }

                // 2. Identify the current user's role and payment status
                final myMember = members.isEmpty
                    ? null
                    : members.firstWhere(
                        (m) => m.customerId == customer.id,
                        orElse: () => members.first,
                      );
                final anyMemberReadyOrPaid = members.any(
                  (m) =>
                      m.status == GroupMemberStatus.ready ||
                      m.status == GroupMemberStatus.paid,
                );
                if (myMember == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                return Scaffold(
                  backgroundColor: scheme.surface,
                  appBar: AppBar(
                    title: const Text('Group Order Summary'),
                    actions: [
                      if (isHost)
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: () =>
                              _showJoinQR(context, groupOrder.joinCode),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmLeaveGroup(context),
                        ),
                    ],
                  ),
                  body: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _JoinCodeHeader(joinCode: groupOrder.joinCode),
                      ),

                      if (isHost)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _DeliverySplitControl(
                                groupOrderId: groupOrderId,
                                currentSplit: groupOrder.deliveryFeeSplit,
                                enabled: !anyMemberReadyOrPaid,
                              ),
                              const SizedBox(height: 12),
                              _TotalSplitControl(
                                groupOrderId: groupOrderId,
                                currentStrategy: groupOrder.totalSplitStrategy,
                                enabled: !anyMemberReadyOrPaid,
                              ),
                            ],
                          ),
                        ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Members (${members.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final member = members[index];

                              double payingForOthers = 0;
                              for (final other in members) {
                                if (other.paidBy == member.customerId) {
                                  payingForOthers +=
                                      memberDetails[other
                                          .customerId]?['baseShare'] ??
                                      0;
                                }
                              }

                              double finalToPay = (member.paidBy != null)
                                  ? payingForOthers
                                  : (memberDetails[member
                                                .customerId]?['baseShare'] ??
                                            0) +
                                        payingForOthers;

                              final payerName = member.paidBy != null
                                  ? members
                                        .firstWhere(
                                          (m) => m.customerId == member.paidBy,
                                          orElse: () => member,
                                        )
                                        .name
                                  : null;

                              return Column(
                                children: [
                                  _MemberTile(
                                    member: member,
                                    baseShare:
                                        memberDetails[member
                                            .customerId]?['baseShare'] ??
                                        0,
                                    finalToPay: finalToPay,
                                    coveredBy: payerName,
                                    isHost:
                                        member.customerId ==
                                        groupOrder.hostCustomerId,
                                    isMe: member.customerId == customer.id,
                                    canRemove:
                                        isHost &&
                                        groupOrder.status ==
                                            GroupOrderStatus.open &&
                                        member.customerId != customer.id,
                                    canCover:
                                        member.customerId != customer.id &&
                                        myMember.status !=
                                            GroupMemberStatus.paid &&
                                        member.paidBy == null &&
                                        member.status != GroupMemberStatus.paid,
                                    onRemove: () =>
                                        _removeMember(context, member),
                                    onCover: () =>
                                        _coverMember(context, member),
                                  ),
                                  if (member.customerId == customer.id &&
                                      member.status ==
                                          GroupMemberStatus.ordering)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await DatabaseService()
                                                .markGroupMemberReady(
                                                  groupOrderId: groupOrderId,
                                                  customerId: customer.id,
                                                );
                                          },
                                          child: const Text('Ready'),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                            childCount: members.length,
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: scheme.outlineVariant.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Total Breakdown',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _BillRow(
                                  label: 'Total Items Subtotal',
                                  value: subtotal,
                                ),
                                _BillRow(
                                  label: 'Combined Tax (15%)',
                                  value: tax,
                                ),
                                _BillRow(
                                  label: 'Delivery Fee',
                                  value: deliveryFee,
                                  suffix:
                                      '(${groupOrder.deliveryFeeSplit.toUpperCase()} SPLIT)',
                                ),
                                const Divider(height: 24),
                                _BillRow(
                                  label: 'Grand Total',
                                  value: grandTotal,
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                  bottomSheet: _BottomActions(
                    isHost: isHost,
                    members: members,
                    hasItems: allItems.isNotEmpty,
                    myStatus: myMember.status,
                    onPlaceOrder: () {
                      if (isHost && myMember.status == GroupMemberStatus.paid) {
                        _placeCoveredHostOrder(context, groupOrder);
                        return;
                      }

                      _navigateToCheckout(
                        context: context,
                        members: members,
                        allItems: allItems,
                        memberDetails: memberDetails,
                        grandTotal: grandTotal,
                        groupOrder: groupOrder,
                      );
                    },
                    hostCustomerId: groupOrder.hostCustomerId,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _navigateToCheckout({
    required BuildContext context,
    required List<GroupOrderMember> members,
    required List<GroupOrderItem> allItems,
    required Map<String, Map<String, double>> memberDetails,
    required double grandTotal,
    required GroupOrder groupOrder,
  }) {
    // 1. Identify what the current user is paying for
    final me = customer.id;
    final isHost = groupOrder.hostCustomerId == customer.id;

    // Items this user is paying for (own items + items of people they covered)
    final itemsUserPaysFor = allItems.where((item) {
      if (item.memberId == me) {
        // Only pay for own items if not covered by someone else
        final myMember = members.firstWhere((m) => m.customerId == me);
        return myMember.paidBy == null;
      }
      // Pay for others if current user is their payer
      final itemOwner = members.firstWhere(
        (m) => m.customerId == item.memberId,
      );
      return itemOwner.paidBy == me;
    }).toList();

    // Calculate the actual amounts to pass to CheckoutScreen
    double paySubtotal = 0;
    double payTax = 0;
    double payDelivery = 0;
    double payTotal = 0;

    // If strategy is equal split, and user is NOT covered by someone else
    final myMember = members.firstWhere((m) => m.customerId == me);
    if (groupOrder.totalSplitStrategy == 'equal' && myMember.paidBy == null) {
      payTotal = grandTotal / members.length;
      // For equal split, we can't easily break down subtotal/tax/delivery per person
      // but we'll approximate it for display in CheckoutScreen
      paySubtotal = payTotal / (1 + kTaxRate);
      payTax = payTotal - paySubtotal;
    } else {
      // Individual items or host pays all
      // Add user's own share if not covered
      if (myMember.paidBy == null) {
        final mine = memberDetails[me]!;
        paySubtotal += mine['subtotal']!;
        payTax += mine['tax']!;
        payDelivery += mine['delivery']!;
        payTotal += mine['baseShare']!;
      }
    }

    // Add shares of anyone this user is covering
    for (final m in members) {
      if (m.paidBy == me) {
        final theirs = memberDetails[m.customerId]!;
        paySubtotal += theirs['subtotal']!;
        payTax += theirs['tax']!;
        payDelivery += theirs['delivery']!;
        payTotal += theirs['baseShare']!;
      }
    }

    if (payTotal <= 0 && myMember.paidBy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your payment is already covered by another member!'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: itemsUserPaysFor
              .map(
                (item) => cart_models.CartItem(
                  id: item.menuItemId,
                  name: item.name,
                  description: item.description,
                  imagePath: item.imageUrl,
                  unitPrice: item.unitPrice,
                  quantity: item.quantity,
                ),
              )
              .toList(),
          checkoutData: cart_models.CheckoutData(
            deliveryFee: payDelivery,
            taxRate: kTaxRate,
            walletBalance: 0, // Will be fetched from stream in CheckoutScreen
          ),
          subtotal: paySubtotal,
          deliveryFee: payDelivery,
          tax: payTax,
          discount: 0,
          total: payTotal,
          customerId: customer.id,
          restaurantId: restaurant.id,
          groupOrderId: groupOrderId,
          isGroupHost: isHost,
        ),
      ),
    );
  }

  void _showJoinQR(BuildContext context, String code) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => _QrSheet(code: code),
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'You will be removed from the group and your items will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().leaveGroupOrder(
        groupOrderId: groupOrderId,
        customerId: customer.id,
      );
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    GroupOrderMember member,
  ) async {
    // Prevent host from removing themselves
    if (member.customerId == customer.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host cannot remove themselves.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Remove ${member.name} and all their items from this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().removeMemberFromGroupOrder(
        groupOrderId: groupOrderId,
        customerId: member.customerId,
      );
    }
  }

  Future<void> _coverMember(
    BuildContext context,
    GroupOrderMember member,
  ) async {
    final myMember = await DatabaseService().getGroupMember(
      groupOrderId: groupOrderId,
      customerId: customer.id,
    );
    if (myMember?.status == GroupMemberStatus.paid) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already paid and cannot cover another member.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cover Payment?'),
        content: Text(
          'Do you want to pay for ${member.name}\'s part of the order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cover Them'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().coverGroupMemberPayment(
          groupOrderId: groupOrderId,
          payerId: customer.id,
          payeeId: member.customerId,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cover member: $e')),
        );
      }
    }
  }

  Future<void> _placeCoveredHostOrder(
    BuildContext context,
    GroupOrder groupOrder,
  ) async {
    try {
      await DatabaseService().placeFinalGroupOrder(
        groupOrderId: groupOrder.id,
        customerId: customer.id,
        restaurantId: restaurant.id,
      );

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Group Order Placed'),
          content: const Text(
            'Everyone has paid. The final group order has been placed successfully.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place group order: $e')),
      );
    }
  }
}

class _ErrorStateScreen extends StatelessWidget {
  const _ErrorStateScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.onPop,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onPop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: theme.colorScheme.error),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPop,
                  child: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrSheet extends StatelessWidget {
  const _QrSheet({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invite Friends',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code or scan the QR to join',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          QrImageView(data: code, version: QrVersions.auto, size: 200),
          const SizedBox(height: 16),
          Text(
            code,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DeliverySplitControl extends StatelessWidget {
  const _DeliverySplitControl({
    required this.groupOrderId,
    required this.currentSplit,
    this.enabled = true,
  });

  final String groupOrderId;
  final String currentSplit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivery Fee Split',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SplitOption(
                label: 'Equal',
                icon: Icons.people_outline,
                isSelected: currentSplit == 'equal',
                onTap: enabled ? () => _updateSplit('equal') : null,
              ),
              const SizedBox(width: 8),
              _SplitOption(
                label: 'Proportional',
                icon: Icons.pie_chart_outline,
                isSelected: currentSplit == 'proportional',
                onTap: enabled ? () => _updateSplit('proportional') : null,
              ),
              const SizedBox(width: 8),
              _SplitOption(
                label: 'Host Pays',
                icon: Icons.person_outline,
                isSelected: currentSplit == 'host',
                onTap: enabled ? () => _updateSplit('host') : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateSplit(String split) {
    DatabaseService().updateGroupOrder(groupOrderId, {
      'deliveryFeeSplit': split,
    });
  }
}

class _TotalSplitControl extends StatelessWidget {
  const _TotalSplitControl({
    required this.groupOrderId,
    required this.currentStrategy,
    this.enabled = true,
  });

  final String groupOrderId;
  final String currentStrategy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Bill Division',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SplitOption(
                label: 'Pay For Own',
                icon: Icons.person_outline,
                isSelected: currentStrategy == 'individual',
                onTap: enabled ? () => _updateStrategy('individual') : null,
              ),
              const SizedBox(width: 8),
              _SplitOption(
                label: 'Split Equally',
                icon: Icons.groups_outlined,
                isSelected: currentStrategy == 'equal',
                onTap: enabled ? () => _updateStrategy('equal') : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateStrategy(String strategy) {
    DatabaseService().updateGroupOrder(groupOrderId, {
      'totalSplitStrategy': strategy,
    });
  }
}

class _SplitOption extends StatelessWidget {
  const _SplitOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary
                : scheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? scheme.onPrimary : scheme.primary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? scheme.onPrimary : scheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinCodeHeader extends StatelessWidget {
  const _JoinCodeHeader({required this.joinCode});

  final String joinCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'JOIN CODE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                joinCode,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: joinCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join code copied!')),
                  );
                },
              ),
            ],
          ),
          const Text(
            'Invite friends to start eating together',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.baseShare,
    required this.finalToPay,
    this.coveredBy,
    required this.isHost,
    required this.isMe,
    required this.canRemove,
    required this.canCover,
    required this.onRemove,
    required this.onCover,
  });

  final GroupOrderMember member;
  final double baseShare;
  final double finalToPay;
  final String? coveredBy;
  final bool isHost;
  final bool isMe;
  final bool canRemove;
  final bool canCover;
  final VoidCallback onRemove;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isHost
              ? Colors.amber.withOpacity(0.2)
              : scheme.primary.withOpacity(0.1),
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
              color: isHost ? Colors.amber[800] : scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isMe) _Badge(label: 'YOU', color: scheme.primary),
            if (isHost) _Badge(label: 'HOST', color: Colors.amber[800]!),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (coveredBy != null)
              Text(
                'Covered by $coveredBy',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              )
            else
              Text(
                'Total to pay: ${finalToPay.toStringAsFixed(2)} SAR',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

            if (finalToPay > baseShare && coveredBy == null)
              Text(
                '(Includes others you covered)',
                style: TextStyle(fontSize: 10, color: scheme.primary),
              ),

            const SizedBox(height: 4),
            _StatusBadge(status: member.status),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCover)
              TextButton.icon(
                onPressed: onCover,
                icon: const Icon(Icons.volunteer_activism_outlined, size: 16),
                label: const Text('Cover', style: TextStyle(fontSize: 11)),
              ),
            if (canRemove)
              IconButton(
                icon: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.redAccent,
                ),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GroupMemberStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case GroupMemberStatus.ready:
        color = Colors.green;
        label = 'Ready';
        icon = Icons.check_circle_outline;
        break;
      case GroupMemberStatus.paid:
        color = Colors.blue;
        label = 'Paid';
        icon = Icons.payments_outlined;
        break;
      default:
        color = Colors.orange;
        label = 'Ordering...';
        icon = Icons.shopping_cart_outlined;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.suffix,
  });

  final String label;
  final double value;
  final bool isTotal;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: isTotal
                    ? theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )
                    : theme.textTheme.bodyMedium,
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
            ],
          ),
          Text(
            '${value.toStringAsFixed(2)} SAR',
            style: isTotal
                ? theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  )
                : theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isHost,
    required this.members,
    required this.hasItems,
    required this.myStatus,
    required this.onPlaceOrder,
    required this.hostCustomerId,
  });

  final bool isHost;
  final List<GroupOrderMember> members;
  final bool hasItems;
  final GroupMemberStatus myStatus;
  final VoidCallback onPlaceOrder;
  final String hostCustomerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allReady =
        members.isNotEmpty &&
        members.every(
          (m) =>
              m.status == GroupMemberStatus.ready ||
              m.status == GroupMemberStatus.paid,
        );

    final isPaid = myStatus == GroupMemberStatus.paid;
    final hostMember =
        members.where((m) => m.customerId == hostCustomerId).isNotEmpty
        ? members.firstWhere((m) => m.customerId == hostCustomerId)
        : null;
    final allNonHostPaid = members
        .where((m) => m.customerId != hostCustomerId)
        .every((m) => m.status == GroupMemberStatus.paid);

    final canHostFinalize =
        isHost && hostMember != null && allNonHostPaid && hasItems;
    final isButtonDisabled =
        !allReady ||
        !hasItems ||
        (!isHost && isPaid) ||
        (isHost && !canHostFinalize);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!allReady)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for all members to confirm their items...',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: isButtonDisabled ? null : onPlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: Text(
                isPaid
                    ? isHost
                          ? 'Place Order'
                          : 'Payment Completed'
                    : isHost
                    ? 'Pay & Place Order'
                    : 'Proceed to Payment',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
