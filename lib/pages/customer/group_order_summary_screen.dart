import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/cart_models.dart' as cart_models;
import 'package:yjeek/models/customer.dart';
import 'package:yjeek/models/group_order.dart';
import 'package:yjeek/models/restaurant.dart';
import 'package:yjeek/pages/customer/checkout_screen.dart';
import 'package:yjeek/pages/customer/order_detail_screen.dart';
import 'package:yjeek/utils/tax.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yjeek/widgets/confirm_dialog.dart';

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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You were removed from the group order.'),
                  ),
                );

                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
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
                // Item line totals already include tax; split it back out for
                // display purposes only.
                final subtotal = allItems.fold<double>(
                  0,
                  (sum, item) => sum + item.lineTotal,
                );
                final tax = subtotal * kTaxRate;
                final subtotalExclTax = subtotal - tax;
                final deliveryFee = restaurant.deliveryFee;
                final grandTotalBeforeDiscount = subtotal + deliveryFee;

                double promoDiscount = 0;
                if (groupOrder.promoDiscountType != null &&
                    groupOrder.promoDiscountValue != null) {
                  final base = subtotal;
                  if (groupOrder.promoDiscountType == 'fixed') {
                    promoDiscount = groupOrder.promoDiscountValue!
                        .clamp(0.0, base)
                        .toDouble();
                  } else {
                    promoDiscount =
                        base * (groupOrder.promoDiscountValue! / 100);
                    if (promoDiscount > base) promoDiscount = base;
                  }
                }
                final grandTotal =
                (grandTotalBeforeDiscount - promoDiscount)
                    .clamp(0.0, double.infinity)
                    .toDouble();

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
                  // Per-User flow:
                  //   x = grandTotal (items + tax + delivery − promo)
                  //   "own"   declarers pay (their items+tax) + delivery/N
                  //   "fixed" declarers pay their declared amount
                  //   y      = x − own − fixed; percent declarers split y by %
                  //   z      = leftover → host
                  final distributable = grandTotal;
                  final perMemberDeliveryShare = members.isEmpty
                      ? 0.0
                      : deliveryFee / members.length;

                  final nonHostMembers = members
                      .where((m) => m.customerId != groupOrder.hostCustomerId)
                      .toList();

                  double sumFixed = 0;
                  double sumPercent = 0;
                  for (final m in nonHostMembers) {
                    if (m.paymentMode == 'fixed') {
                      sumFixed += (m.paymentValue ?? 0);
                    } else if (m.paymentMode == 'percent') {
                      sumPercent += (m.paymentValue ?? 0);
                    }
                  }

                  // mSubtotalById already includes tax (it's the items' gross),
                  // so don't add mTaxById again or tax gets double-counted.
                  final Map<String, double> ownShareById = {};
                  double sumOwn = 0;
                  for (final m in nonHostMembers) {
                    if (m.paymentMode != 'own') continue;
                    final share = (mSubtotalById[m.customerId] ?? 0) +
                        perMemberDeliveryShare;
                    ownShareById[m.customerId] = share;
                    sumOwn += share;
                  }

                  if (sumPercent > 100 + 0.005) {
                    perUserOvercommitted = true;
                  }
                  if (sumFixed + sumOwn > distributable + 0.005) {
                    perUserOvercommitted = true;
                  }

                  final percentBase =
                  (distributable - sumFixed - sumOwn)
                      .clamp(0.0, double.infinity)
                      .toDouble();

                  for (final m in nonHostMembers) {
                    double share;
                    switch (m.paymentMode) {
                      case 'fixed':
                        share = (m.paymentValue ?? 0)
                            .clamp(0, distributable)
                            .toDouble();
                        break;
                      case 'percent':
                        final v = (m.paymentValue ?? 0).clamp(0, 100);
                        share = percentBase * v / 100;
                        break;
                      case 'own':
                      default:
                        share = ownShareById[m.customerId] ?? 0.0;
                        break;
                    }
                    memberDetails[m.customerId] = {
                      'subtotal': mSubtotalById[m.customerId] ?? 0,
                      'tax': mTaxById[m.customerId] ?? 0,
                      'delivery':
                      m.paymentMode == 'own' ? perMemberDeliveryShare : 0.0,
                      'baseShare': share,
                    };
                  }

                  final declaredTotal = sumFixed +
                      sumOwn +
                      (percentBase * sumPercent.clamp(0, 100) / 100);
                  final hostLeftover =
                  (distributable - declaredTotal)
                      .clamp(0.0, double.infinity)
                      .toDouble();
                  memberDetails[groupOrder.hostCustomerId] = {
                    'subtotal':
                    mSubtotalById[groupOrder.hostCustomerId] ?? 0,
                    'tax': mTaxById[groupOrder.hostCustomerId] ?? 0,
                    'delivery': 0.0,
                    'baseShare': hostLeftover,
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
                    title: Text(
                      'Group Order Summary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    centerTitle: true,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Divider(height: 1, color: scheme.outlineVariant),
                    ),
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
                              _PromoCodeControl(
                                groupOrderId: groupOrderId,
                                restaurantId: restaurant.id,
                                promoCode: groupOrder.promoCode,
                                promoLabel: groupOrder.promoLabel,
                                discount: promoDiscount,
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
                                    otherMembersPercentSum: members
                                        .where(
                                          (m) =>
                                      m.customerId != member.customerId &&
                                          m.customerId !=
                                              groupOrder.hostCustomerId &&
                                          m.paymentMode == 'percent',
                                    )
                                        .fold<double>(
                                      0,
                                          (s, m) =>
                                      s + (m.paymentValue ?? 0),
                                    ),
                                  ),
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
                              color: scheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Total Breakdown',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _BillRow(
                                  label: 'Total Items Subtotal',
                                  value: subtotalExclTax,
                                ),
                                _BillRow(
                                  label: 'Combined Tax (15%)',
                                  value: tax,
                                ),
                                _BillRow(
                                  label: 'Delivery Fee',
                                  value: deliveryFee,
                                ),
                                if (promoDiscount > 0) ...[
                                  _BillRow(
                                    label: groupOrder.promoLabel != null &&
                                        groupOrder.promoLabel!.isNotEmpty
                                        ? 'Discount (${groupOrder.promoLabel})'
                                        : 'Discount',
                                    value: -promoDiscount,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: scheme.outlineVariant,
                                ),
                                const SizedBox(height: 14),
                                _BillRow(
                                  label: 'Order Total',
                                  value: grandTotal,
                                  isTotal: true,
                                ),
                                _PaymentPlanSection(
                                  members: members,
                                  memberDetails: memberDetails,
                                  hostCustomerId: groupOrder.hostCustomerId,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                          MediaQuery
                              .viewPaddingOf(context)
                              .bottom + 220,
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
                    myCoveredByName: myMember.paidBy == null
                        ? null
                        : members
                        .firstWhere(
                          (m) => m.customerId == myMember.paidBy,
                      orElse: () => myMember,
                    )
                        .name,
                    perUserOvercommitted: perUserOvercommitted,
                    onPlaceOrder: () {
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
    final me = customer.id;
    final isHost = groupOrder.hostCustomerId == customer.id;
    final myMember = members.firstWhere((m) => m.customerId == me);

    // Group-wide totals (full order; used for the host's summary view).
    final fullSubtotal =
    allItems.fold<double>(0, (s, i) => s + i.lineTotal);
    final fullTax = fullSubtotal * kTaxRate;
    final fullDelivery = restaurant.deliveryFee;

    double promoDiscount = 0;
    if (groupOrder.promoDiscountType != null &&
        groupOrder.promoDiscountValue != null) {
      final base = fullSubtotal + fullTax;
      if (groupOrder.promoDiscountType == 'fixed') {
        promoDiscount =
            groupOrder.promoDiscountValue!.clamp(0.0, base).toDouble();
      } else {
        promoDiscount = base * (groupOrder.promoDiscountValue! / 100);
        if (promoDiscount > base) promoDiscount = base;
      }
    }

    final appliedCoupon = (groupOrder.promoCode ?? '').isNotEmpty
        ? cart_models.Coupon(
      code: groupOrder.promoCode!,
      label: groupOrder.promoLabel ?? '',
      discountType: groupOrder.promoDiscountType == 'fixed'
          ? cart_models.CouponDiscountType.fixed
          : cart_models.CouponDiscountType.percentage,
      discountValue: groupOrder.promoDiscountValue ?? 0,
    )
        : null;

    // Items shown on the checkout cart list.
    final itemsUserPaysFor = isHost
        ? allItems
        : allItems.where((item) {
      if (item.memberId == me) {
        return myMember.paidBy == null;
      }
      final itemOwner = members.firstWhere(
            (m) => m.customerId == item.memberId,
      );
      return itemOwner.paidBy == me;
    }).toList();

    double paySubtotal = 0;
    double payTax = 0;
    double payDelivery = 0;
    double payTotal = 0;
    String? contributionNote;
    List<MapEntry<String, double>>? othersPaid;

    if (isHost) {
      // Host always sees the full order summary.
      paySubtotal = fullSubtotal;
      payTax = fullTax;
      payDelivery = fullDelivery;

      if (groupOrder.totalSplitStrategy == 'host') {
        payTotal = grandTotal;
        contributionNote =
        'Host Covers All — you are paying for everyone\'s share.';
      } else if (groupOrder.totalSplitStrategy == 'equal') {
        payTotal = members.isEmpty ? 0 : grandTotal / members.length;
        contributionNote =
        'Split Equally — your share is 1/${members.length} of the group total.';
      } else {
        payTotal = memberDetails[me]?['baseShare'] ?? 0;
        contributionNote =
        'Per-User split — you cover whatever members didn\'t declare.';
      }
    } else if (groupOrder.totalSplitStrategy == 'equal' &&
        myMember.paidBy == null) {
      payTotal = grandTotal / members.length;
      paySubtotal = payTotal / (1 + kTaxRate);
      payTax = payTotal - paySubtotal;
      contributionNote =
      'Split Equally — your share is 1/${members.length} of the group total.';
    } else if (myMember.paidBy == null) {
      final mine = memberDetails[me]!;
      paySubtotal += mine['subtotal']!;
      payTax += mine['tax']!;
      payDelivery += mine['delivery']!;
      payTotal += mine['baseShare']!;

      switch (myMember.paymentMode) {
        case 'fixed':
          contributionNote =
          'You declared a fixed contribution of ${(myMember.paymentValue ?? 0)
              .toStringAsFixed(2)} SAR. The host covers the rest.';
          break;
        case 'percent':
          contributionNote =
          'You declared ${(myMember.paymentValue ?? 0).toStringAsFixed(
              0)}% of the remaining group total.';
          break;
        case 'own':
        default:
          contributionNote =
          'Paying your own items + tax + your share of the delivery fee.';
          break;
      }
    }

    // Add shares of anyone this user is covering. For the host, paySubtotal /
    // payTax / payDelivery are already the full order, so only the payTotal
    // needs to absorb covered members' shares; for non-hosts every field
    // needs the bump.
    for (final m in members) {
      if (m.paidBy == me) {
        final theirs = memberDetails[m.customerId]!;
        if (!isHost) {
          paySubtotal += theirs['subtotal']!;
          payTax += theirs['tax']!;
          payDelivery += theirs['delivery']!;
        }
        payTotal += theirs['baseShare']!;
      }
    }

    // "Paid by others" rows for the host's summary view.
    if (isHost && groupOrder.totalSplitStrategy != 'host') {
      final paid = <MapEntry<String, double>>[];
      for (final m in members) {
        if (m.customerId == me) continue;
        if (m.status != GroupMemberStatus.paid) continue;
        if (m.paidBy != null) continue;
        final own = memberDetails[m.customerId]?['baseShare'] ?? 0;
        final coveredAmt = members
            .where((o) => o.paidBy == m.customerId)
            .fold<double>(
          0,
              (s, o) =>
          s + (memberDetails[o.customerId]?['baseShare'] ?? 0),
        );
        final amt = own + coveredAmt;
        if (amt <= 0.005) continue;
        paid.add(MapEntry(m.name, amt));
      }
      if (paid.isNotEmpty) othersPaid = paid;
    }

    if (payTotal <= 0 && myMember.paidBy != null && !isHost) {
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
                  selectedOptions: item.selectedOptions,
                ),
              )
              .toList(),
          checkoutData: cart_models.CheckoutData(
            deliveryFee: payDelivery,
            taxRate: kTaxRate,
            walletBalance: 0,
          ),
          subtotal: paySubtotal - payTax,
          deliveryFee: payDelivery,
          tax: payTax,
          discount: isHost ? promoDiscount : 0,
          total: payTotal,
          appliedCoupon: isHost ? appliedCoupon : null,
          customerId: customer.id,
          restaurantId: restaurant.id,
          groupOrderId: groupOrderId,
          isGroupHost: isHost,
          groupContributionNote: contributionNote,
          groupOthersPaid: othersPaid,
        ),
      ),
    );
  }

  void _showJoinQR(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => _QrJoinDialog(code: code),
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context) async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Leave Group?',
      message:
          'You will be removed from the group and your items will be deleted.',
      confirmLabel: 'Leave',
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
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Remove Member?',
      message: 'Remove ${member.name} and all their items from this order?',
      confirmLabel: 'Remove',
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

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Cover Payment?',
      message:
      "Do you want to pay for ${member.name}'s part of the order?",
      confirmLabel: 'Yes, Cover Them',
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
      final placed = await DatabaseService().placeFinalGroupOrder(
        groupOrderId: groupOrder.id,
        customerId: customer.id,
        restaurantId: restaurant.id,
      );

      if (!context.mounted) return;

      final theme = Theme.of(context);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) =>
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Group Order Placed!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Everyone has paid. The final group order has been placed successfully.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('View order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );

      if (!context.mounted) return;

      if (placed != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailScreen(
                  order: placed,
                  customer: customer,
                ),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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

class _QrJoinDialog extends StatelessWidget {
  const _QrJoinDialog({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      clipBehavior: Clip.antiAlias,
      backgroundColor: scheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'JOIN CODE',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  code,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: scheme.onPrimary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Join code copied!')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_all_rounded,
                            color: scheme.onPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Copy Code',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Text(
              'Invite friends to start eating together',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 180,
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? scheme.error.withOpacity(0.35)
              : scheme.outlineVariant,
          width: 1,
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

class _PromoCodeControl extends StatefulWidget {
  const _PromoCodeControl({
    required this.groupOrderId,
    required this.restaurantId,
    required this.promoCode,
    required this.promoLabel,
    required this.discount,
    required this.enabled,
  });

  final String groupOrderId;
  final String restaurantId;
  final String? promoCode;
  final String? promoLabel;
  final double discount;
  final bool enabled;

  @override
  State<_PromoCodeControl> createState() => _PromoCodeControlState();
}

class _PromoCodeControlState extends State<_PromoCodeControl> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await DatabaseService().applyGroupPromoCode(
        groupOrderId: widget.groupOrderId,
        restaurantId: widget.restaurantId,
        code: code,
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await DatabaseService().clearGroupPromoCode(widget.groupOrderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPromo = (widget.promoCode ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Promo Code',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _LockPill(locked: !widget.enabled),
            ],
          ),
          const SizedBox(height: 14),
          if (hasPromo) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: scheme.onPrimary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (widget.promoLabel ?? '').isNotEmpty
                          ? '${widget.promoCode}  ·  ${widget.promoLabel}'
                          : widget.promoCode!,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.discount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '−${widget.discount.toStringAsFixed(2)} SAR',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (widget.enabled) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _busy ? null : _remove,
                      child: Icon(Icons.close,
                          color: scheme.onPrimary, size: 18),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            if (widget.enabled) ...[
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Enter promo code',
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: (_) => _busy ? null : _apply(),
                      ),
                    ),
                    Material(
                      color: scheme.primary,
                      child: InkWell(
                        onTap: _busy ? null : _apply,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          child: _busy
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                              : Text(
                            'Apply',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              ...[
                Text(
                  'No promo code applied.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
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
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
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
          if (hostPaysAll) ...[
            const SizedBox(height: 6),
            Text(
              'Delivery follows Host Covers All.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CompactSplitOption(
                    label: 'Split Equally',
                    icon: Icons.people_outline,
                    preview: '${perPerson.toStringAsFixed(2)} SAR each',
                    isSelected: currentSplit == 'equal',
                    onTap: enabled && !hostPaysAll
                        ? () => _updateSplit('equal')
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactSplitOption(
                    label: 'Host Pays',
                    icon: Icons.person_outline,
                    preview: '${deliveryFee.toStringAsFixed(2)} SAR',
                    isSelected: currentSplit == 'host',
                    onTap: enabled && !hostPaysAll
                        ? () => _updateSplit('host')
                        : null,
                  ),
                ),
              ],
            ),
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
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1),
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
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CompactSplitOption(
                    label: 'Per User',
                    icon: Icons.person_outline,
                    preview: 'Members choose',
                    isSelected: currentStrategy == 'individual',
                    onTap: enabled
                        ? () => _updateStrategy('individual')
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactSplitOption(
                    label: 'Equal',
                    icon: Icons.groups_outlined,
                    preview: '${equalShare.toStringAsFixed(2)} each',
                    isSelected: currentStrategy == 'equal',
                    onTap: enabled ? () => _updateStrategy('equal') : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactSplitOption(
                    label: 'Host All',
                    icon: Icons.workspace_premium_outlined,
                    preview: '${grandTotal.toStringAsFixed(2)} by host',
                    isSelected: currentStrategy == 'host',
                    onTap: enabled ? () => _updateStrategy('host') : null,
                  ),
                ),
              ],
            ),
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

class _PaymentPlanSection extends StatelessWidget {
  const _PaymentPlanSection({
    required this.members,
    required this.memberDetails,
    required this.hostCustomerId,
  });

  final List<GroupOrderMember> members;
  final Map<String, Map<String, double>> memberDetails;
  final String hostCustomerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (members.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    double hostShare = 0;

    for (final m in members) {
      if (m.paidBy != null) continue;

      final own = memberDetails[m.customerId]?['baseShare'] ?? 0;
      final coveredFor = members
          .where((o) => o.paidBy == m.customerId)
          .toList();
      final coveredAmt = coveredFor.fold<double>(
        0,
            (s, o) => s + (memberDetails[o.customerId]?['baseShare'] ?? 0),
      );
      final amount = own + coveredAmt;
      final isHostMember = m.customerId == hostCustomerId;

      if (isHostMember) {
        hostShare = amount;
        continue;
      }

      if (amount <= 0.005) continue;

      final hasPaid = m.status == GroupMemberStatus.paid;
      final coveredNames = coveredFor.map((o) => o.name).join(', ');

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasPaid
                    ? Icons.check_circle
                    : Icons.account_balance_wallet_outlined,
                color: hasPaid ? Colors.green : scheme.outline,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coveredAmt > 0)
                      Text(
                        'incl. cover for $coveredNames',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '-${amount.toStringAsFixed(2)} SAR',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Always render the host's row so the host can see what they need to pay.
    final hostMember = members
        .where((m) => m.customerId == hostCustomerId)
        .toList();
    if (hostMember.isNotEmpty) {
      final host = hostMember.first;
      final hostPaid = host.status == GroupMemberStatus.paid;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hostPaid ? Icons.check_circle : Icons.person_outline,
                color: hostPaid ? Colors.green : scheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        host.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '(host pays)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${hostShare.toStringAsFixed(2)} SAR',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        const SizedBox(height: 14),
        Text(
          'Payment Plan',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _CompactSplitOption extends StatelessWidget {
  const _CompactSplitOption({
    required this.label,
    required this.icon,
    required this.preview,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? scheme.onPrimary : scheme.primary,
                  size: 22,
                ),
                const Spacer(),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isSelected ? scheme.onPrimary : scheme.outline,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: locked ? scheme.surfaceContainerHighest : scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 13,
            color: locked ? scheme.onSurfaceVariant : scheme.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            locked ? 'Locked' : 'Editable',
            style: TextStyle(
              color: locked ? scheme.onSurfaceVariant : scheme.onPrimary,
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
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: enabled ? onReady : null,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor: scheme.surfaceContainerHigh,
              disabledForegroundColor: scheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(label),
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
    this.otherMembersPercentSum = 0,
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
  final double otherMembersPercentSum;

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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) _Badge(label: 'YOU', color: scheme.primary),
                        if (isHost)
                          _Badge(label: 'HOST', color: Colors.amber[800]!),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (coveredBy != null)
                      Text(
                        'Covered by $coveredBy',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        'Total to pay: ${finalToPay.toStringAsFixed(2)} SAR',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    if (finalToPay > baseShare && coveredBy == null)
                      Text(
                        '(Includes others you covered)',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
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
            const SizedBox(height: 12),
            if (canEditPayment)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) =>
                          _PaymentModeSheet(
                            groupOrderId: groupOrderId,
                            memberId: member.customerId,
                            currentMode: member.paymentMode,
                            currentValue: member.paymentValue,
                            otherMembersPercentSum: otherMembersPercentSum,
                          ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: scheme.onPrimaryContainer,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your contribution',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimaryContainer
                                      .withOpacity(0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _paymentDeclarationLabel(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          color: scheme.onPrimaryContainer,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
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
    this.otherMembersPercentSum = 0,
  });

  final String groupOrderId;
  final String memberId;
  final String currentMode;
  final double? currentValue;
  final double otherMembersPercentSum;

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
      final raw = _valueCtrl.text.trim();
      value = double.tryParse(raw);
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number.')),
        );
        return;
      }
      if (value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mode == 'percent'
                  ? 'Percentage cannot be negative.'
                  : 'Amount cannot be negative.',
            ),
          ),
        );
        return;
      }
      if (_mode == 'percent') {
        if (value > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Percentage cannot exceed 100.')),
          );
          return;
        }
        // Whole-number percentages only — flag decimals up front instead
        // of silently truncating.
        if ((value - value.roundToDouble()).abs() > 0.0001) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Use a whole-number percentage (e.g. 10, not 10.3).',
              ),
            ),
          );
          return;
        }
        final allowed = (100 - widget.otherMembersPercentSum).clamp(0, 100);
        if (value > allowed + 0.005) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'The total % would exceed 100%. Remaining is ${allowed
                    .toStringAsFixed(0)}%.',
              ),
            ),
          );
          return;
        }
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
        top: 8,
        bottom: MediaQuery
            .viewInsetsOf(context)
            .bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How will you pay?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Declarations are applied in order. Host covers the rest.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          _ModeChoice(
            label: 'My own share',
            description: 'Pay for the items you ordered (plus tax).',
            selected: _mode == 'own',
            onTap: () => setState(() => _mode = 'own'),
          ),
          const SizedBox(height: 8),
          _ModeChoice(
            label: 'Fixed amount',
            description: 'I will pay a specific number of SAR.',
            selected: _mode == 'fixed',
            onTap: () => setState(() => _mode = 'fixed'),
          ),
          const SizedBox(height: 8),
          _ModeChoice(
            label: 'Percentage',
            description: 'I will pay a % of the remaining balance.',
            selected: _mode == 'percent',
            onTap: () => setState(() => _mode = 'percent'),
          ),
          if (needsValue) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.numberWithOptions(
                decimal: _mode != 'percent',
                signed: false,
              ),
              decoration: InputDecoration(
                labelText: _mode == 'percent' ? 'Percentage (0-100)' : 'SAR',
                suffixText: _mode == 'percent' ? '%' : 'SAR',
                border: const OutlineInputBorder(),
                helperText: _mode == 'percent'
                    ? 'Whole numbers only.'
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
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
                  fontWeight: FontWeight.w800,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
              fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  )
                : theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
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
    this.perUserOvercommitted = false,
    this.myPaidBy,
    this.myCoveredByName,
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
  final bool perUserOvercommitted;
  final String? myPaidBy;
  final String? myCoveredByName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isPaid = myStatus == GroupMemberStatus.paid;
    final iAmCovered = !isHost && isPaid && myPaidBy != null;

    Future<void> acknowledgeCovered(BuildContext ctx) async {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) =>
            AlertDialog(
              icon: const Icon(
                Icons.volunteer_activism_outlined,
                color: Colors.green,
                size: 40,
              ),
              title: const Text('Your share is covered'),
              content: Text(
                myCoveredByName == null
                    ? 'Another member has paid for your share. You\'re all set — the order will arrive with the rest of the group.'
                    : '$myCoveredByName has paid for your share. You\'re all set — the order will arrive with the rest of the group.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (!ctx.mounted) return;
      Navigator.of(ctx).popUntil((route) => route.isFirst);
    }
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
    final isButtonDisabled =
        !iAmCovered &&
            (!hasItems ||
                !currentMemberHasItems ||
                !hostReady ||
                !allReady ||
                (!isHost && hostPaysAll) ||
                (!isHost && isPaid) ||
                (isHost && !canHostFinalize) ||
                perUserOvercommitted);
    return Container(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isButtonDisabled
                    ? null
                    : iAmCovered
                    ? () => acknowledgeCovered(context)
                    : onPlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: Text(
                  iAmCovered
                      ? 'Your Share is Covered — Tap to Finish'
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
          ),
        ],
      ),
    );
  }
}
