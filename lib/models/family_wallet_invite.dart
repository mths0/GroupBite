import 'package:yjeek/models/family_wallet_member.dart';

enum InviteStatus { pending, accepted, rejected }

InviteStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'accepted':
      return InviteStatus.accepted;
    case 'rejected':
      return InviteStatus.rejected;
    case 'pending':
    default:
      return InviteStatus.pending;
  }
}

class FamilyWalletInvite {
  final String id;
  final String walletId;
  final String ownerId;
  final String ownerName;
  final String inviteeId;
  final String inviteePhone;
  final InviteStatus status;
  final double? inviteeLimit;
  final LimitPeriod inviteePeriod;

  const FamilyWalletInvite({
    required this.id,
    required this.walletId,
    required this.ownerId,
    required this.ownerName,
    required this.inviteeId,
    required this.inviteePhone,
    required this.status,
    required this.inviteeLimit,
    required this.inviteePeriod,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'walletId': walletId,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'inviteeId': inviteeId,
        'inviteePhone': inviteePhone,
        'status': status.name,
        'inviteeLimit': inviteeLimit,
        'inviteePeriod': inviteePeriod.name,
      };

  factory FamilyWalletInvite.fromMap(Map<String, dynamic> map) {
    final rawLimit = map['inviteeLimit'];
    return FamilyWalletInvite(
      id: (map['id'] ?? '').toString(),
      walletId: (map['walletId'] ?? '').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString(),
      inviteeId: (map['inviteeId'] ?? '').toString(),
      inviteePhone: (map['inviteePhone'] ?? '').toString(),
      status: _statusFromString(map['status']?.toString()),
      inviteeLimit: rawLimit is num ? rawLimit.toDouble() : null,
      inviteePeriod: limitPeriodFromString(map['inviteePeriod']?.toString()),
    );
  }
}

enum FamilyWalletInviteResult {
  ok,
  notFound,
  notCustomer,
  alreadyInWallet,
  alreadyInvited,
  self,
}
