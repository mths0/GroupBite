import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/family_wallet_invite.dart';
import 'package:food_delivery_platform/models/family_wallet_member.dart';
import 'package:food_delivery_platform/pages/customer/add_funds_sheet.dart';
import 'package:food_delivery_platform/widgets/confirm_dialog.dart';

class FamilyWalletTab extends StatefulWidget {
  const FamilyWalletTab({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<FamilyWalletTab> createState() => _FamilyWalletTabState();
}

class _FamilyWalletTabState extends State<FamilyWalletTab>
    with AutomaticKeepAliveClientMixin {
  final DatabaseService _db = DatabaseService();

  @override
  bool get wantKeepAlive => true;

  Future<void> _createWallet() async {
    try {
      await _db.createFamilyWallet(
        ownerId: widget.customerId,
        ownerName: widget.customerName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create wallet: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<FamilyWallet?>(
      stream: _db.streamFamilyWalletForUser(widget.customerId),
      builder: (context, walletSnap) {
        if (walletSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final wallet = walletSnap.data;
        if (wallet != null) {
          return _WalletView(
            wallet: wallet,
            currentUserId: widget.customerId,
            db: _db,
          );
        }

        return StreamBuilder<List<FamilyWalletInvite>>(
          stream: _db.streamPendingInvites(widget.customerId),
          builder: (context, inviteSnap) {
            final invites = inviteSnap.data ?? [];
            if (invites.isNotEmpty) {
              return _InviteListView(invites: invites, db: _db);
            }
            return _NoWalletView(onCreate: _createWallet);
          },
        );
      },
    );
  }
}

class _NoWalletView extends StatelessWidget {
  const _NoWalletView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Family Wallet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a wallet with family members. The owner adds funds; everyone can pay from it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create Family Wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteListView extends StatelessWidget {
  const _InviteListView({required this.invites, required this.db});
  final List<FamilyWalletInvite> invites;
  final DatabaseService db;

  Future<void> _accept(BuildContext context, String inviteId) async {
    try {
      await db.acceptFamilyWalletInvite(inviteId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _reject(BuildContext context, String inviteId) async {
    try {
      await db.rejectFamilyWalletInvite(inviteId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = invites.first;
    final rest = invites.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Text(
          "You're Invited",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: first.ownerName,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' invited you to their family wallet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _reject(context, first.id),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: scheme.outlineVariant),
              foregroundColor: scheme.onSurface,
            ),
            child: const Text(
              'Decline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _accept(context, first.id),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Accept Invitation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 32),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 20),
          Text(
            'Other invitations',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...rest.map(
                (invite) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${invite.ownerName} invited you',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _reject(context, invite.id),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(
                                      color: scheme.outlineVariant),
                                  foregroundColor: scheme.onSurface,
                                ),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _accept(context, invite.id),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ],
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView({
    required this.wallet,
    required this.currentUserId,
    required this.db,
  });

  final FamilyWallet wallet;
  final String currentUserId;
  final DatabaseService db;

  bool get isOwner => wallet.isOwner(currentUserId);

  Future<void> _addFunds(BuildContext context) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFundsSheet(
        customerId: currentUserId,
        title: 'Add funds to Family Wallet',
      ),
    );
    if (amount == null || amount <= 0) return;

    try {
      await db.addFundsToFamilyWallet(walletId: wallet.id, amount: amount);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add funds: $e')),
      );
    }
  }

  Future<void> _addMember(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMemberSheet(
        walletId: wallet.id,
        ownerId: wallet.ownerId,
        ownerName: wallet.ownerName,
        db: db,
      ),
    );
  }

  Future<void> _removeMember(BuildContext context, String memberId) async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Remove member?',
      message: 'They will lose access to the family wallet immediately.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true) return;
    try {
      await db.removeFamilyWalletMember(
        walletId: wallet.id,
        memberId: memberId,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: $e')),
      );
    }
  }

  Future<void> _editLimit(
    BuildContext context,
    String memberId,
    FamilyWalletMember? member,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditLimitSheet(
        walletId: wallet.id,
        memberId: memberId,
        member: member,
        db: db,
      ),
    );
  }

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Leave family wallet?',
      message: 'You will lose access to the shared balance.',
      confirmLabel: 'Leave',
    );
    if (confirmed != true) return;
    try {
      await db.leaveFamilyWallet(walletId: wallet.id, userId: currentUserId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave: $e')),
      );
    }
  }

  Future<void> _deleteWallet(BuildContext context) async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Delete family wallet?',
      message:
          'Balance of ${wallet.balance.toStringAsFixed(2)} SAR will be refunded to your personal wallet. Members will lose access.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) return;
    try {
      await db.deleteFamilyWallet(walletId: wallet.id, ownerId: wallet.ownerId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Icon(
                  Icons.family_restroom,
                  size: 120,
                  color: scheme.onPrimary.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FAMILY WALLET',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SAR',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        wallet.balance.toStringAsFixed(2),
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 18),
                    Material(
                      color: scheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _addFunds(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: scheme.onSecondaryContainer,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Top Up',
                                style: TextStyle(
                                  color: scheme.onSecondaryContainer,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (isOwner) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addMember(context),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text(
                'Add Member',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 14),

        // Members
        Row(
          children: [
            Expanded(
              child: Text(
                'Members',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isOwner)
              IconButton(
                tooltip: 'Delete Family Wallet',
                onPressed: () => _deleteWallet(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.ownerName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _RoleBadge(
                      label: 'Owner',
                      background: scheme.primary,
                      foreground: scheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<FamilyWalletMember>>(
          stream: db.streamFamilyWalletMembers(wallet.id),
          builder: (context, snap) {
            final byId = {
              for (final m in (snap.data ?? const <FamilyWalletMember>[]))
                m.userId: m
            };
            return Column(
              children: [
                for (final memberId in wallet.memberIds) ...[
                  _MemberTile(
                    memberId: memberId,
                    member:
                    (isOwner || memberId == currentUserId)
                        ? byId[memberId]
                        : null,
                    isCurrentUser: memberId == currentUserId,
                    isOwnerView: isOwner,
                    onRemove: () => _removeMember(context, memberId),
                    onLeave: () => _leave(context),
                    onEdit: () => _editLimit(context, memberId, byId[memberId]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),

        if (isOwner) ...[
          const SizedBox(height: 24),
          _PendingInvitesSection(walletId: wallet.id, db: db),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.memberId,
    required this.member,
    required this.isCurrentUser,
    required this.isOwnerView,
    required this.onRemove,
    required this.onLeave,
    required this.onEdit,
  });

  final String memberId;
  final FamilyWalletMember? member;
  final bool isCurrentUser;
  final bool isOwnerView;
  final VoidCallback onRemove;
  final VoidCallback onLeave;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final db = DatabaseService();

    final m = member;
    final hasLimit = m != null && m.limit != null;
    final spent = m == null ? 0.0 : m.effectiveSpent(DateTime.now());
    final progress = hasLimit ? (spent / m.limit!).clamp(0.0, 1.0) : 0.0;
    final atOrOverLimit = hasLimit && spent >= m.limit!;

    final actions = <Widget>[];
    if (isOwnerView) {
      actions.add(IconButton(
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: onRemove,
        tooltip: 'Remove',
        color: scheme.error,
        visualDensity: VisualDensity.compact,
      ));
    } else if (isCurrentUser) {
      actions.add(IconButton(
        icon: const Icon(Icons.exit_to_app),
        onPressed: onLeave,
        tooltip: 'Leave',
        color: scheme.error,
        visualDensity: VisualDensity.compact,
      ));
    }

    return FutureBuilder(
      future: db.getUserById(memberId),
      builder: (context, snap) {
        final name = snap.data?.name ?? memberId;

        return Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant, width: 1),
          ),
          child: InkWell(
            onTap: isOwnerView ? onEdit : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _RoleBadge(
                              label: 'Member',
                              background: scheme.surfaceContainerHigh,
                              foreground: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  if (m != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Spending',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (hasLimit)
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: spent.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: atOrOverLimit
                                        ? scheme.error
                                        : scheme.onSurface,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / ${m.limit!.toStringAsFixed(0)} SAR',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                        ),
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Text(
                            'No limit',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (hasLimit) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHigh,
                          valueColor: AlwaysStoppedAnimation(
                            atOrOverLimit ? scheme.error : scheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          limitPeriodLabel(m.period),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PendingInvitesSection extends StatelessWidget {
  const _PendingInvitesSection({required this.walletId, required this.db});
  final String walletId;
  final DatabaseService db;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<FamilyWalletInvite>>(
      stream: db.streamWalletPendingInvites(walletId),
      builder: (context, snap) {
        final invites = snap.data ?? [];
        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Invites',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...invites.map(
              (invite) => Card(
                child: ListTile(
                  leading: const Icon(Icons.hourglass_empty),
                  title: Text(invite.inviteePhone),
                  subtitle: const Text('Awaiting response'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel invite',
                    onPressed: () => db.rejectFamilyWalletInvite(invite.id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({
    required this.walletId,
    required this.ownerId,
    required this.ownerName,
    required this.db,
  });

  final String walletId;
  final String ownerId;
  final String ownerName;
  final DatabaseService db;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _phoneController = TextEditingController();
  final _limitController = TextEditingController();
  LimitPeriod _period = LimitPeriod.manual;
  String? _error;
  bool _busy = false;

  bool get _hasLimit => _limitController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _limitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  String _resultMessage(FamilyWalletInviteResult r) {
    switch (r) {
      case FamilyWalletInviteResult.notFound:
        return 'No user found with this phone number';
      case FamilyWalletInviteResult.notCustomer:
        return 'This user is not a customer';
      case FamilyWalletInviteResult.alreadyInWallet:
        return 'This user is already in a family wallet';
      case FamilyWalletInviteResult.alreadyInvited:
        return 'You already invited this user';
      case FamilyWalletInviteResult.self:
        return 'You cannot invite yourself';
      case FamilyWalletInviteResult.ok:
        return '';
    }
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a phone number');
      return;
    }

    double? limit;
    if (_hasLimit) {
      limit = double.tryParse(_limitController.text.trim());
      if (limit == null || limit <= 0) {
        setState(() => _error = 'Enter a valid limit (or leave blank)');
        return;
      }
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final result = await widget.db.inviteToFamilyWallet(
        walletId: widget.walletId,
        ownerId: widget.ownerId,
        ownerName: widget.ownerName,
        phone: phone,
        limit: limit,
        period: limit == null ? LimitPeriod.manual : _period,
      );

      if (!mounted) return;
      if (result == FamilyWalletInviteResult.ok) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Invite sent')),
        );
      } else {
        setState(() {
          _error = _resultMessage(result);
          _busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Member',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SheetLabel('Phone Number'),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                autofocus: true,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _error,
                  errorStyle: TextStyle(color: scheme.error),
                ),
              ),
              const SizedBox(height: 18),
              _SheetLabel('Limit'),
              const SizedBox(height: 8),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  hintText: 'Spending Limit (optional)',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
              ),
              const SizedBox(height: 18),
              _SheetLabel('How the limit resets'),
              const SizedBox(height: 8),
              DropdownButtonFormField<LimitPeriod>(
                initialValue: _period,
                onChanged: _hasLimit
                    ? (v) =>
                    setState(() => _period = v ?? LimitPeriod.manual)
                    : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.restart_alt_outlined),
                ),
                items: LimitPeriod.values
                    .map(
                      (p) =>
                      DropdownMenuItem(
                        value: p,
                        child: Text(_resetCadenceLabel(p)),
                      ),
                )
                    .toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Send Invite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _resetCadenceLabel(LimitPeriod p) {
  switch (p) {
    case LimitPeriod.daily:
      return 'Daily';
    case LimitPeriod.weekly:
      return 'Weekly';
    case LimitPeriod.monthly:
      return 'Monthly';
    case LimitPeriod.manual:
      return 'Manual';
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditLimitSheet extends StatefulWidget {
  const _EditLimitSheet({
    required this.walletId,
    required this.memberId,
    required this.member,
    required this.db,
  });

  final String walletId;
  final String memberId;
  final FamilyWalletMember? member;
  final DatabaseService db;

  @override
  State<_EditLimitSheet> createState() => _EditLimitSheetState();
}

class _EditLimitSheetState extends State<_EditLimitSheet> {
  late final TextEditingController _limitController;
  late LimitPeriod _period;
  bool _busy = false;
  String? _error;

  bool get _hasLimit => _limitController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _limitController = TextEditingController(
      text: m?.limit == null ? '' : m!.limit!.toStringAsFixed(0),
    );
    _period = m?.period ?? LimitPeriod.manual;
    _limitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    double? limit;
    if (_hasLimit) {
      limit = double.tryParse(_limitController.text.trim());
      if (limit == null || limit <= 0) {
        setState(() => _error = 'Enter a valid limit (or leave blank)');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.db.setMemberLimit(
        walletId: widget.walletId,
        userId: widget.memberId,
        limit: limit,
        period: limit == null ? LimitPeriod.manual : _period,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _resetSpend() async {
    setState(() => _busy = true);
    try {
      await widget.db.resetMemberSpend(
        walletId: widget.walletId,
        userId: widget.memberId,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _removeLimit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.db.setMemberLimit(
        walletId: widget.walletId,
        userId: widget.memberId,
        limit: null,
        period: LimitPeriod.manual,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showResetButton = _period == LimitPeriod.manual &&
        (widget.member?.spentInPeriod ?? 0) > 0;
    final hasExistingLimit = widget.member?.limit != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit Limit',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SheetLabel('Limit'),
              const SizedBox(height: 8),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Spending Limit',
                  prefixIcon: const Icon(Icons.speed_outlined),
                  errorText: _error,
                  errorStyle: TextStyle(color: scheme.error),
                ),
              ),
              const SizedBox(height: 18),
              _SheetLabel('How the limit resets'),
              const SizedBox(height: 8),
              DropdownButtonFormField<LimitPeriod>(
                initialValue: _period,
                onChanged: _hasLimit
                    ? (v) =>
                    setState(() => _period = v ?? LimitPeriod.manual)
                    : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.restart_alt_outlined),
                ),
                items: LimitPeriod.values
                    .map(
                      (p) =>
                      DropdownMenuItem(
                        value: p,
                        child: Text(_resetCadenceLabel(p)),
                      ),
                )
                    .toList(),
              ),
              if (showResetButton) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _resetSpend,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerLowest,
                    foregroundColor: scheme.onSurface,
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text(
                    'Reset spending',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (hasExistingLimit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _removeLimit,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.errorContainer.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: scheme.error,
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.do_not_disturb_alt_outlined),
                  label: const Text(
                    'Remove limit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
