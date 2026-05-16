import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/cart_models.dart' as cart_models;
import 'package:food_delivery_platform/models/customer.dart';
import 'package:food_delivery_platform/models/group_order.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/pages/customer/checkout_screen.dart';
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
          final expired = groupOrder?.cancelledReason == 'expired';
          return _ErrorStateScreen(
            icon: expired ? Icons.timer_off_outlined : Icons.cancel_outlined,
            title: expired ? 'Group Order Closed' : 'Order Cancelled',
            message: expired
                ? 'The group order timer ended and any paid amounts were refunded to wallets.'
                : 'This group order is no longer available.',
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
              return const _KickedScreen();
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
                final coupon = groupOrder.coupon;
                double discount = 0;
                if (coupon != null) {
                  if (coupon.discountType ==
                      cart_models.CouponDiscountType.percentage) {
                    discount = (subtotal + tax) * (coupon.discountValue / 100);
                  } else {
                    discount = coupon.discountValue;
                  }
                  discount = discount.clamp(0, subtotal + tax).toDouble();
                }
                final grandTotal = subtotal + tax + deliveryFee - discount;

                // Per-member items totals (used by all strategies).
                final Map<String, double> mSubtotalById = {};
                final Map<String, double> mTaxById = {};
                for (final member in members) {
                  final mSub = allItems
                      .where((i) => i.memberId == member.customerId)
                      .fold<double>(0, (s, i) => s + i.lineTotal);
                  mSubtotalById[member.customerId] = mSub;
                  mTaxById[member.customerId] = mSub * kTaxRate;
                }

                final Map<String, Map<String, double>> memberDetails = {};
                bool perUserOvercommitted = false;

                if (groupOrder.totalSplitStrategy == 'equal') {
                  final share = members.isEmpty
                      ? 0.0
                      : grandTotal / members.length;
                  for (final member in members) {
                    memberDetails[member.customerId] = {
                      'subtotal': mSubtotalById[member.customerId] ?? 0,
                      'tax': mTaxById[member.customerId] ?? 0,
                      'delivery': members.isEmpty
                          ? 0.0
                          : deliveryFee / members.length,
                      'baseShare': share,
                    };
                  }
                } else if (groupOrder.totalSplitStrategy == 'host') {
                  for (final member in members) {
                    final isHostMember =
                        member.customerId == groupOrder.hostCustomerId;
                    memberDetails[member.customerId] = {
                      'subtotal': mSubtotalById[member.customerId] ?? 0,
                      'tax': mTaxById[member.customerId] ?? 0,
                      'delivery': isHostMember ? deliveryFee : 0.0,
                      'baseShare': isHostMember ? grandTotal : 0.0,
                    };
                  }
                } else {
                  // Per-User: sequential declarations against a running
                  // remaining balance. When delivery is on the host the
                  // distributable total excludes delivery.
                  final hostCoversDelivery =
                      groupOrder.deliveryFeeSplit == 'host';
                  final distributable = hostCoversDelivery
                      ? subtotal + tax
                      : grandTotal;

                  final nonHostMembers = members
                      .where((m) => m.customerId != groupOrder.hostCustomerId)
                      .toList()
                    ..sort((a, b) {
                      final ad =
                          a.paymentDeclaredAt ??
                          DateTime.fromMillisecondsSinceEpoch(
                            8640000000000000,
                          );
                      final bd =
                          b.paymentDeclaredAt ??
                          DateTime.fromMillisecondsSinceEpoch(
                            8640000000000000,
                          );
                      return ad.compareTo(bd);
                    });

                  double remaining = distributable;
                  for (final member in nonHostMembers) {
                    double share;
                    switch (member.paymentMode) {
                      case 'fixed':
                        final v = member.paymentValue ?? 0;
                        share = v.clamp(0, remaining).toDouble();
                        if (v > remaining + 0.005) perUserOvercommitted = true;
                        break;
                      case 'percent':
                        final v = (member.paymentValue ?? 0).clamp(0, 100);
                        share = remaining * v / 100;
                        break;
                      case 'own':
                      default:
                        share =
                            (mSubtotalById[member.customerId] ?? 0) +
                            (mTaxById[member.customerId] ?? 0);
                        share = share.clamp(0, remaining).toDouble();
                        break;
                    }
                    memberDetails[member.customerId] = {
                      'subtotal': mSubtotalById[member.customerId] ?? 0,
                      'tax': mTaxById[member.customerId] ?? 0,
                      'delivery': 0.0,
                      'baseShare': share,
                    };
                    remaining -= share;
                  }

                  final hostShare =
                      (remaining < 0 ? 0.0 : remaining) +
                      (hostCoversDelivery ? deliveryFee : 0.0);
                  memberDetails[groupOrder.hostCustomerId] = {
                    'subtotal':
                        mSubtotalById[groupOrder.hostCustomerId] ?? 0,
                    'tax': mTaxById[groupOrder.hostCustomerId] ?? 0,
                    'delivery': hostCoversDelivery ? deliveryFee : 0.0,
                    'baseShare': hostShare,
                  };
                }

                // 2. Identify the current user's role and payment status
                final myMember = members.isEmpty
                    ? null
                    : members.firstWhere(
                        (m) => m.customerId == customer.id,
                        orElse: () => members.first,
                      );
                final hostMemberMatches = members.where(
                  (m) => m.customerId == groupOrder.hostCustomerId,
                );
                final hostMember = hostMemberMatches.isEmpty
                    ? null
                    : hostMemberMatches.first;
                final hostReady =
                    hostMember?.status == GroupMemberStatus.ready ||
                    hostMember?.status == GroupMemberStatus.paid;
                final allMembersHaveItems =
                    members.isNotEmpty &&
                    members.every(
                      (m) => allItems.any((i) => i.memberId == m.customerId),
                    );
                final allReady =
                    members.isNotEmpty &&
                    members.every(
                      (m) =>
                          m.status == GroupMemberStatus.ready ||
                          m.status == GroupMemberStatus.paid,
                    );
                final currentMemberHasItems = allItems.any(
                  (i) => i.memberId == customer.id,
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

                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _GroupOrderTimerCard(
                            key: ValueKey(groupOrder.expiresAt),
                            groupOrderId: groupOrderId,
                            expiresAt: groupOrder.expiresAt,
                            isHost: isHost,
                            hostCustomerId: groupOrder.hostCustomerId,
                          ),
                        ),
                      ),

                      if (isHost)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _DeliverySplitControl(
                                groupOrderId: groupOrderId,
                                currentSplit: groupOrder.deliveryFeeSplit,
                                deliveryFee: deliveryFee,
                                memberCount: members.length,
                                currentStrategy: groupOrder.totalSplitStrategy,
                                enabled: isHost && !hostReady,
                              ),
                              const SizedBox(height: 12),
                              _TotalSplitControl(
                                groupOrderId: groupOrderId,
                                currentStrategy: groupOrder.totalSplitStrategy,
                                grandTotal: grandTotal,
                                memberCount: members.length,
                                enabled: isHost && !hostReady,
                              ),
                              const SizedBox(height: 12),
                              _CouponCard(
                                groupOrderId: groupOrderId,
                                restaurantId: restaurant.id,
                                currentCoupon: groupOrder.coupon,
                                enabled: !hostReady,
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
                                  Builder(
                                    builder: (context) {
                                      final isCurrentMember =
                                          member.customerId == customer.id;
                                      final memberHasItems = allItems.any(
                                        (i) => i.memberId == member.customerId,
                                      );
                                      final isMemberHost =
                                          member.customerId ==
                                          groupOrder.hostCustomerId;
                                      final canMarkReady =
                                          isCurrentMember &&
                                          member.status ==
                                              GroupMemberStatus.ordering &&
                                          memberHasItems &&
                                          (isMemberHost ? true : hostReady);
                                      final disabledMessage = memberHasItems
                                          ? 'Waiting for host to lock the split.'
                                          : 'Add at least one item before marking ready.';

                                      return _MemberReadyAction(
                                        visible:
                                            isCurrentMember &&
                                            member.status ==
                                                GroupMemberStatus.ordering,
                                        enabled: canMarkReady,
                                        label: isMemberHost
                                            ? 'Lock Split & Ready'
                                            : 'Agree & Ready',
                                        disabledMessage: disabledMessage,
                                        onReady: () async {
                                          await DatabaseService()
                                              .markGroupMemberReady(
                                                groupOrderId: groupOrderId,
                                                customerId: customer.id,
                                              );
                                        },
                                      );
                                    },
                                  ),
                                  _MemberTile(
                                    member: member,
                                    items: allItems
                                        .where(
                                          (i) =>
                                              i.memberId == member.customerId,
                                        )
                                        .toList(),
                                    groupOrderId: groupOrderId,
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
                                    canMutateItems:
                                        member.customerId == customer.id &&
                                        member.status ==
                                            GroupMemberStatus.ordering,
                                    totalSplitStrategy:
                                        groupOrder.totalSplitStrategy,
                                    canEditPayment:
                                        member.customerId == customer.id &&
                                        member.customerId !=
                                            groupOrder.hostCustomerId &&
                                        member.status ==
                                            GroupMemberStatus.ordering &&
                                        groupOrder.totalSplitStrategy ==
                                            'individual',
                                    canRemove:
                                        isHost &&
                                        groupOrder.status ==
                                            GroupOrderStatus.open &&
                                        member.customerId != customer.id,
                                    canCover:
                                        member.customerId != customer.id &&
                                        groupOrder.totalSplitStrategy !=
                                            'host' &&
                                        hostReady &&
                                        allReady &&
                                        myMember.status !=
                                            GroupMemberStatus.paid &&
                                        member.paidBy == null &&
                                        member.status != GroupMemberStatus.paid,
                                    onRemove: () =>
                                        _removeMember(context, member),
                                    onCover: () =>
                                        _coverMember(context, member),
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
                                if (coupon != null && discount > 0)
                                  _BillRow(
                                    label: 'Discount',
                                    value: -discount,
                                    suffix: '(${coupon.code})',
                                  ),
                                const Divider(height: 24),
                                _BillRow(
                                  label: 'Grand Total',
                                  value: grandTotal,
                                  isTotal: true,
                                ),
                                if (members.any(
                                  (m) => m.status == GroupMemberStatus.paid,
                                )) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Paid by',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...members
                                      .where(
                                        (m) =>
                                            m.status ==
                                            GroupMemberStatus.paid,
                                      )
                                      .map((m) {
                                        final amount =
                                            memberDetails[m
                                                .customerId]?['baseShare'] ??
                                            0.0;
                                        final coverer = m.paidBy == null
                                            ? null
                                            : (members
                                                  .where(
                                                    (x) =>
                                                        x.customerId ==
                                                        m.paidBy,
                                                  )
                                                  .isEmpty
                                                  ? null
                                                  : members
                                                        .firstWhere(
                                                          (x) =>
                                                              x.customerId ==
                                                              m.paidBy,
                                                        )
                                                        .name);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  coverer != null
                                                      ? '${m.name} (covered by $coverer)'
                                                      : m.name,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                '${amount.toStringAsFixed(2)} SAR',
                                                style: theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              MediaQuery.viewPaddingOf(context).bottom + 220,
                        ),
                      ),
                    ],
                  ),
                  bottomSheet: _BottomActions(
                    isHost: isHost,
                    members: members,
                    hasItems: allItems.isNotEmpty,
                    allMembersHaveItems: allMembersHaveItems,
                    hostReady: hostReady,
                    allReady: allReady,
                    currentMemberHasItems: currentMemberHasItems,
                    totalSplitStrategy: groupOrder.totalSplitStrategy,
                    myStatus: myMember.status,
                    myPaidBy: myMember.paidBy,
                    perUserOvercommitted: perUserOvercommitted,
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
      if (groupOrder.totalSplitStrategy == 'host') {
        return isHost;
      }

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
    if (groupOrder.totalSplitStrategy == 'host') {
      if (isHost) {
        paySubtotal = memberDetails.values.fold<double>(
          0,
          (sum, details) => sum + (details['subtotal'] ?? 0),
        );
        payTax = memberDetails.values.fold<double>(
          0,
          (sum, details) => sum + (details['tax'] ?? 0),
        );
        payDelivery = restaurant.deliveryFee;
        payTotal = grandTotal;
      }
    } else if (groupOrder.totalSplitStrategy == 'equal' &&
        myMember.paidBy == null) {
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

class _GroupOrderTimerCard extends StatefulWidget {
  const _GroupOrderTimerCard({
    super.key,
    required this.groupOrderId,
    required this.expiresAt,
    required this.isHost,
    required this.hostCustomerId,
  });

  final String groupOrderId;
  final DateTime expiresAt;
  final bool isHost;
  final String hostCustomerId;

  @override
  State<_GroupOrderTimerCard> createState() => _GroupOrderTimerCardState();
}

class _GroupOrderTimerCardState extends State<_GroupOrderTimerCard> {
  Timer? _timer;
  bool _isExtending = false;
  bool _didRequestClose = false;

  Duration get _remaining => widget.expiresAt.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant _GroupOrderTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _didRequestClose = false;
      _startTicker();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _closeIfExpired();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeIfExpired());
  }

  Future<void> _closeIfExpired() async {
    if (_didRequestClose || _remaining > Duration.zero) return;
    _didRequestClose = true;
    await DatabaseService().expireGroupOrderIfNeeded(
      groupOrderId: widget.groupOrderId,
    );
  }

  Future<void> _extendTimer() async {
    setState(() => _isExtending = true);
    try {
      await DatabaseService().extendGroupOrderTimer(
        groupOrderId: widget.groupOrderId,
        hostCustomerId: widget.hostCustomerId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not extend timer: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExtending = false);
    }
  }

  String _formatRemaining(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = _remaining;
    final expired = remaining <= Duration.zero;
    final urgent = remaining.inSeconds <= 120;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgent
            ? scheme.errorContainer.withOpacity(0.45)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? scheme.error.withOpacity(0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                color: urgent ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                expired
                    ? 'Group order closing'
                    : 'Closes in ${_formatRemaining(remaining)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: urgent ? scheme.error : scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isHost
                ? 'Only the host can extend the timer.'
                : 'Ask the host to extend if the group needs more time.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (widget.isHost)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: expired || _isExtending ? null : _extendTimer,
                  icon: _isExtending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_alarm_outlined),
                  label: const Text('Extend 10 min'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeliverySplitControl extends StatelessWidget {
  const _DeliverySplitControl({
    required this.groupOrderId,
    required this.currentSplit,
    required this.deliveryFee,
    required this.memberCount,
    required this.currentStrategy,
    this.enabled = true,
  });

  final String groupOrderId;
  final String currentSplit;
  final double deliveryFee;
  final int memberCount;
  final String currentStrategy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hostPaysAll = currentStrategy == 'host';
    final perPerson = memberCount == 0 ? 0.0 : deliveryFee / memberCount;

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
              const Spacer(),
              _LockPill(locked: !enabled),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hostPaysAll
                ? 'Delivery follows Host Covers All.'
                : 'Choose how the delivery fee is divided before locking the split.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _SplitOption(
                label: 'Equal',
                icon: Icons.people_outline,
                description: 'Everyone pays the same delivery share.',
                preview: '${perPerson.toStringAsFixed(2)} SAR each',
                isSelected: currentSplit == 'equal',
                onTap: enabled && !hostPaysAll
                    ? () => _updateSplit('equal')
                    : null,
              ),
              const SizedBox(height: 8),
              _SplitOption(
                label: 'By item total',
                icon: Icons.pie_chart_outline,
                description: 'Higher item subtotal pays more of delivery.',
                preview: 'Weighted by subtotal',
                isSelected: currentSplit == 'proportional',
                onTap: enabled && !hostPaysAll
                    ? () => _updateSplit('proportional')
                    : null,
              ),
              const SizedBox(height: 8),
              _SplitOption(
                label: 'Host Pays',
                icon: Icons.person_outline,
                description: 'Only the host pays the delivery fee.',
                preview: '${deliveryFee.toStringAsFixed(2)} SAR by host',
                isSelected: currentSplit == 'host',
                onTap: enabled && !hostPaysAll
                    ? () => _updateSplit('host')
                    : null,
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
    required this.grandTotal,
    required this.memberCount,
    this.enabled = true,
  });

  final String groupOrderId;
  final String currentStrategy;
  final double grandTotal;
  final int memberCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final equalShare = memberCount == 0 ? 0.0 : grandTotal / memberCount;

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
              const Spacer(),
              _LockPill(locked: !enabled),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how item subtotal, tax, and delivery are assigned.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _SplitOption(
                label: 'Per User',
                icon: Icons.person_outline,
                description:
                    'Each member declares their share (fixed, percent, or own items). Host covers the rest.',
                preview: 'Members choose',
                isSelected: currentStrategy == 'individual',
                onTap: enabled ? () => _updateStrategy('individual') : null,
              ),
              const SizedBox(height: 8),
              _SplitOption(
                label: 'Split Equally',
                icon: Icons.groups_outlined,
                description: 'Everyone pays the same grand-total share.',
                preview: '${equalShare.toStringAsFixed(2)} SAR each',
                isSelected: currentStrategy == 'equal',
                onTap: enabled ? () => _updateStrategy('equal') : null,
              ),
              const SizedBox(height: 8),
              _SplitOption(
                label: 'Host Covers All',
                icon: Icons.workspace_premium_outlined,
                description: 'Members only agree. Host pays the full order.',
                preview: '${grandTotal.toStringAsFixed(2)} SAR by host',
                isSelected: currentStrategy == 'host',
                onTap: enabled ? () => _updateStrategy('host') : null,
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
    required this.description,
    required this.preview,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final String preview;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurface;
    final muted = isSelected
        ? scheme.onPrimary.withOpacity(0.78)
        : scheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? scheme.onPrimary : scheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  preview,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isSelected ? scheme.onPrimary : scheme.outline,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LockPill extends StatelessWidget {
  const _LockPill({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: locked
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 13,
            color: locked ? scheme.outline : scheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            locked ? 'Locked' : 'Editable',
            style: TextStyle(
              color: locked ? scheme.outline : scheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberReadyAction extends StatelessWidget {
  const _MemberReadyAction({
    required this.visible,
    required this.enabled,
    required this.label,
    required this.disabledMessage,
    required this.onReady,
  });

  final bool visible;
  final bool enabled;
  final String label;
  final String disabledMessage;
  final Future<void> Function() onReady;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                disabledMessage,
                style: TextStyle(
                  color: scheme.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: enabled ? onReady : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(label),
          ),
        ],
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
    required this.items,
    required this.groupOrderId,
    required this.baseShare,
    required this.finalToPay,
    this.coveredBy,
    required this.isHost,
    required this.isMe,
    required this.canMutateItems,
    required this.totalSplitStrategy,
    required this.canEditPayment,
    required this.canRemove,
    required this.canCover,
    required this.onRemove,
    required this.onCover,
  });

  final GroupOrderMember member;
  final List<GroupOrderItem> items;
  final String groupOrderId;
  final double baseShare;
  final double finalToPay;
  final String? coveredBy;
  final bool isHost;
  final bool isMe;
  final bool canMutateItems;
  final String totalSplitStrategy;
  final bool canEditPayment;
  final bool canRemove;
  final bool canCover;
  final VoidCallback onRemove;
  final VoidCallback onCover;

  String _customizationSummary(GroupOrderItem item) {
    if (item.selectedOptions.isEmpty) return '';
    return item.selectedOptions
        .map((o) => '${o.groupTitle}: ${o.choiceName}')
        .join(' • ');
  }

  String _paymentDeclarationLabel() {
    switch (member.paymentMode) {
      case 'fixed':
        return 'Paying ${(member.paymentValue ?? 0).toStringAsFixed(2)} SAR';
      case 'percent':
        return 'Paying ${(member.paymentValue ?? 0).toStringAsFixed(0)}%';
      case 'own':
      default:
        return 'Paying own share';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) _Badge(label: 'YOU', color: scheme.primary),
                        if (isHost)
                          _Badge(label: 'HOST', color: Colors.amber[800]!),
                      ],
                    ),
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
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: member.status),
                  ],
                ),
              ),
              if (canCover)
                TextButton.icon(
                  onPressed: onCover,
                  icon: const Icon(
                    Icons.volunteer_activism_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'Cover',
                    style: TextStyle(fontSize: 11),
                  ),
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
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withOpacity(0.4),
                ),
              ),
              child: Column(
                children: items.map((item) {
                  final summary = _customizationSummary(item);
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: items.length > 1 ? 6 : 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (summary.isNotEmpty)
                                Text(
                                  summary,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.outline,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              Text(
                                '${item.lineTotal.toStringAsFixed(2)} SAR',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canMutateItems) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 22,
                            ),
                            onPressed: () async {
                              try {
                                await DatabaseService()
                                    .decrementGroupOrderItem(
                                      groupOrderId: groupOrderId,
                                      memberId: member.customerId,
                                      itemId: item.id,
                                    );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 22,
                            ),
                            onPressed: () async {
                              try {
                                await DatabaseService()
                                    .incrementGroupOrderItem(
                                      groupOrderId: groupOrderId,
                                      memberId: member.customerId,
                                      itemId: item.id,
                                    );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () async {
                              try {
                                await DatabaseService()
                                    .removeGroupOrderItem(
                                      groupOrderId: groupOrderId,
                                      memberId: member.customerId,
                                      itemId: item.id,
                                    );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                          ),
                        ] else
                          Text(
                            'x${item.quantity}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (totalSplitStrategy == 'individual' && !isHost) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: scheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _paymentDeclarationLabel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canEditPayment)
                  TextButton.icon(
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => _PaymentModeSheet(
                          groupOrderId: groupOrderId,
                          memberId: member.customerId,
                          currentMode: member.paymentMode,
                          currentValue: member.paymentValue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentModeSheet extends StatefulWidget {
  const _PaymentModeSheet({
    required this.groupOrderId,
    required this.memberId,
    required this.currentMode,
    required this.currentValue,
  });

  final String groupOrderId;
  final String memberId;
  final String currentMode;
  final double? currentValue;

  @override
  State<_PaymentModeSheet> createState() => _PaymentModeSheetState();
}

class _PaymentModeSheetState extends State<_PaymentModeSheet> {
  late String _mode;
  late final TextEditingController _valueCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.currentMode;
    _valueCtrl = TextEditingController(
      text: widget.currentValue == null
          ? ''
          : widget.currentValue!.toStringAsFixed(
              widget.currentMode == 'percent' ? 0 : 2,
            ),
    );
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    double? value;
    if (_mode != 'own') {
      value = double.tryParse(_valueCtrl.text.trim());
      if (value == null || value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a positive amount.')),
        );
        return;
      }
      if (_mode == 'percent' && value > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Percentage cannot exceed 100.')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await DatabaseService().setGroupMemberPayment(
        groupOrderId: widget.groupOrderId,
        memberId: widget.memberId,
        mode: _mode,
        value: value,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needsValue = _mode != 'own';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How will you pay?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Declarations are applied in order. Host covers the rest.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            _ModeChoice(
              label: 'My own share',
              description: 'Pay for the items I ordered.',
              selected: _mode == 'own',
              onTap: () => setState(() => _mode = 'own'),
            ),
            const SizedBox(height: 6),
            _ModeChoice(
              label: 'Fixed amount',
              description: 'I will pay a specific SAR amount.',
              selected: _mode == 'fixed',
              onTap: () => setState(() => _mode = 'fixed'),
            ),
            const SizedBox(height: 6),
            _ModeChoice(
              label: 'Percentage',
              description: 'I will pay a % of the remaining balance.',
              selected: _mode == 'percent',
              onTap: () => setState(() => _mode = 'percent'),
            ),
            if (needsValue) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _valueCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: _mode == 'percent'
                      ? 'Percentage (0-100)'
                      : 'SAR',
                  suffixText: _mode == 'percent' ? '%' : 'SAR',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.onPrimary : scheme.outline,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected
                          ? scheme.onPrimary.withOpacity(0.78)
                          : scheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
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
    required this.allMembersHaveItems,
    required this.hostReady,
    required this.allReady,
    required this.currentMemberHasItems,
    required this.totalSplitStrategy,
    required this.myStatus,
    required this.onPlaceOrder,
    required this.hostCustomerId,
    required this.myPaidBy,
    this.perUserOvercommitted = false,
  });

  final bool isHost;
  final List<GroupOrderMember> members;
  final bool hasItems;
  final bool allMembersHaveItems;
  final bool hostReady;
  final bool allReady;
  final bool currentMemberHasItems;
  final String totalSplitStrategy;
  final GroupMemberStatus myStatus;
  final VoidCallback onPlaceOrder;
  final String hostCustomerId;
  final String? myPaidBy;
  final bool perUserOvercommitted;

  String? _payerName() {
    if (myPaidBy == null) return null;
    final match = members.where((m) => m.customerId == myPaidBy);
    return match.isEmpty ? null : match.first.name;
  }

  Future<void> _showCompletedDialog(BuildContext context) async {
    final payer = _payerName();
    final body = payer != null
        ? 'Your share has been paid for by $payer.'
        : 'Your payment was successful.';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('All done'),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isPaid = myStatus == GroupMemberStatus.paid;
    final hostMember =
        members.where((m) => m.customerId == hostCustomerId).isNotEmpty
        ? members.firstWhere((m) => m.customerId == hostCustomerId)
        : null;
    final allNonHostPaid = members
        .where((m) => m.customerId != hostCustomerId)
        .every((m) => m.status == GroupMemberStatus.paid);

    final hostPaysAll = totalSplitStrategy == 'host';
    final canHostFinalize =
        isHost &&
        hostMember != null &&
        hasItems &&
        allReady &&
        (hostPaysAll || allNonHostPaid);
    final memberDoneAcknowledge = !isHost && isPaid;
    final isButtonDisabled = memberDoneAcknowledge
        ? false
        : !hasItems ||
            !currentMemberHasItems ||
            !hostReady ||
            !allReady ||
            (!isHost && hostPaysAll) ||
            (isHost && !canHostFinalize) ||
            perUserOvercommitted;
    final statusMessage = !hasItems
        ? 'Add items before continuing.'
        : !allMembersHaveItems
        ? 'Waiting for every member to add at least one item.'
        : perUserOvercommitted
        ? 'Member declarations exceed the order total — please lower one.'
        : !hostReady
        ? 'Host can still change the split. Host must lock it first.'
        : !allReady
        ? 'Waiting for all members to agree to the split.'
        : isHost && !hostPaysAll && !allNonHostPaid
        ? 'Members pay first. Host pays last to place the order.'
        : null;

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
          if (statusMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: const TextStyle(
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
              onPressed: isButtonDisabled
                  ? null
                  : memberDoneAcknowledge
                  ? () => _showCompletedDialog(context)
                  : onPlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: Text(
                memberDoneAcknowledge
                    ? (myPaidBy != null
                          ? 'Your share is covered — Tap to finish'
                          : 'Payment Completed — Tap to finish')
                    : isPaid
                    ? isHost
                          ? 'Place Order'
                          : 'Payment Completed'
                    : !isHost && hostPaysAll
                    ? 'Covered by Host'
                    : isHost
                    ? hostPaysAll
                          ? 'Pay Full Order'
                          : 'Pay & Place Order'
                    : 'Proceed to Payment',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatefulWidget {
  const _CouponCard({
    required this.groupOrderId,
    required this.restaurantId,
    required this.currentCoupon,
    required this.enabled,
  });

  final String groupOrderId;
  final String restaurantId;
  final cart_models.Coupon? currentCoupon;
  final bool enabled;

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  final TextEditingController _controller = TextEditingController();
  bool _validating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _validating = true);
    try {
      final coupon = await DatabaseService().validateCoupon(
        restaurantId: widget.restaurantId,
        code: code,
      );
      if (coupon == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired code.')),
        );
        return;
      }
      await DatabaseService().setGroupOrderCoupon(
        groupOrderId: widget.groupOrderId,
        coupon: coupon,
      );
      _controller.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${coupon.label} applied.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _remove() async {
    try {
      await DatabaseService().setGroupOrderCoupon(
        groupOrderId: widget.groupOrderId,
        coupon: null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final applied = widget.currentCoupon;

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
                Icons.local_offer_outlined,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Promo Code',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _LockPill(locked: !widget.enabled),
            ],
          ),
          const SizedBox(height: 12),
          if (applied != null)
            Chip(
              avatar: Icon(
                Icons.check_circle_outline,
                color: scheme.onPrimaryContainer,
                size: 18,
              ),
              label: Text(
                '${applied.code} · ${applied.label}',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: scheme.primaryContainer,
              deleteIcon: Icon(
                Icons.close,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
              onDeleted: widget.enabled ? _remove : null,
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.enabled && !_validating ? _apply : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                  ),
                  child: _validating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KickedScreen extends StatefulWidget {
  const _KickedScreen();

  @override
  State<_KickedScreen> createState() => _KickedScreenState();
}

class _KickedScreenState extends State<_KickedScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_shown) return;
    _shown = true;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Removed from group'),
        content: const Text(
          'The host removed you from this group order.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(
                context,
              ).popUntil((r) => r.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
