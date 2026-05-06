import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/family_wallet.dart';
import 'package:food_delivery_platform/models/family_wallet_invite.dart';
import 'package:food_delivery_platform/models/family_wallet_member.dart';
import 'package:food_delivery_platform/pages/customer/add_funds_sheet.dart';

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Family Wallet Invitations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...invites.map(
          (invite) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${invite.ownerName} invited you to their family wallet',
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
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _accept(context, invite.id),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: const Text(
          'They will lose access to the family wallet immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave family wallet?'),
        content: const Text('You will lose access to the shared balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Center(child: const Text('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete family wallet?'),
        content: Text(
          'Balance of ${wallet.balance.toStringAsFixed(2)} SAR will be refunded to your personal wallet. Members will lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Center(child: const Text('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      children: [
        // Balance card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.family_restroom, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      wallet.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${wallet.balance.toStringAsFixed(2)} SAR',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _addFunds(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add funds'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Members
        Text(
          'Members',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primary,
              child: Text(
                wallet.ownerName.isNotEmpty
                    ? wallet.ownerName[0].toUpperCase()
                    : 'O',
                style: TextStyle(color: scheme.onPrimary),
              ),
            ),
            title: Text(wallet.ownerName),
            trailing: Chip(
              label: const Text('Owner'),
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.primaryContainer,
            ),
          ),
        ),
        StreamBuilder<List<FamilyWalletMember>>(
          stream: db.streamFamilyWalletMembers(wallet.id),
          builder: (context, snap) {
            final byId = {
              for (final m in (snap.data ?? const <FamilyWalletMember>[]))
                m.userId: m
            };
            return Column(
              children: wallet.memberIds.map((memberId) {
                final m = byId[memberId];
                final showProgress = isOwner || memberId == currentUserId;
                return _MemberTile(
                  memberId: memberId,
                  member: showProgress ? m : null,
                  isCurrentUser: memberId == currentUserId,
                  isOwnerView: isOwner,
                  onRemove: () => _removeMember(context, memberId),
                  onLeave: () => _leave(context),
                  onEdit: () => _editLimit(context, memberId, m),
                );
              }).toList(),
            );
          },
        ),

        if (isOwner) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addMember(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add Member'),
            ),
          ),
          const SizedBox(height: 24),
          _PendingInvitesSection(walletId: wallet.id, db: db),
          const SizedBox(height: 24),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteWallet(context),
                icon: Icon(Icons.delete_outline, color: scheme.error),
                label: Text(
                  'Delete Family Wallet',
                  style: TextStyle(color: scheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.error),
                ),
              ),
            ),
          ),
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
    final showProgressBar = m != null;

    String subtitle;
    if (m == null) {
      subtitle = 'No limit';
    } else if (m.limit == null) {
      subtitle = 'No limit';
    } else {
      subtitle =
          '${spent.toStringAsFixed(0)} / ${m.limit!.toStringAsFixed(0)} SAR  ·  ${limitPeriodLabel(m.period)}';
    }

    final trailingButtons = <Widget>[];
    if (isOwnerView) {
      trailingButtons.add(IconButton(
        icon: const Icon(Icons.tune),
        onPressed: onEdit,
        tooltip: 'Edit limit',
      ));
      trailingButtons.add(IconButton(
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: onRemove,
        tooltip: 'Remove',
      ));
    } else if (isCurrentUser) {
      trailingButtons.add(IconButton(
        icon: const Icon(Icons.exit_to_app),
        onPressed: onLeave,
        tooltip: 'Leave',
      ));
    }

    return FutureBuilder(
      future: db.getUserById(memberId),
      builder: (context, snap) {
        final name = snap.data?.name ?? memberId;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHigh,
                  child: Text(initial),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: atOrOverLimit
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (showProgressBar && hasLimit) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHigh,
                            valueColor: AlwaysStoppedAnimation(
                              atOrOverLimit
                                  ? scheme.error
                                  : scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...trailingButtons,
              ],
            ),
          ),
        );
      },
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
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Member',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              maxLength: 9,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                errorText: _error,
                errorStyle: TextStyle(color: scheme.error),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Spending Limit (optional)',
                hintText: 'Leave blank for no limit',
                prefixIcon: Icon(Icons.speed_outlined),
                suffixText: 'SAR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LimitPeriod>(
              value: _period,
              onChanged: _hasLimit
                  ? (v) => setState(() => _period = v ?? LimitPeriod.manual)
                  : null,
              decoration: InputDecoration(
                labelText: 'Reset',
                prefixIcon: const Icon(Icons.event_repeat),
                border: const OutlineInputBorder(),
                helperText:
                    _hasLimit ? null : 'Set a limit to choose a reset cadence',
              ),
              items: LimitPeriod.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(limitPeriodLabel(p)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Invite'),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showResetButton = _period == LimitPeriod.manual &&
        (widget.member?.spentInPeriod ?? 0) > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Limit',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limitController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Spending Limit',
                hintText: 'Leave blank for no limit',
                prefixIcon: const Icon(Icons.speed_outlined),
                suffixText: 'SAR',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorStyle: TextStyle(color: scheme.error),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LimitPeriod>(
              value: _period,
              onChanged: _hasLimit
                  ? (v) => setState(() => _period = v ?? LimitPeriod.manual)
                  : null,
              decoration: InputDecoration(
                labelText: 'Reset',
                prefixIcon: const Icon(Icons.event_repeat),
                border: const OutlineInputBorder(),
                helperText: _hasLimit
                    ? 'Changing the period resets the spent total'
                    : 'Set a limit to choose a reset cadence',
              ),
              items: LimitPeriod.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(limitPeriodLabel(p)),
                      ))
                  .toList(),
            ),
            if (showResetButton) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _resetSpend,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset spending'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
