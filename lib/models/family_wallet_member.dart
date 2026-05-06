import 'package:cloud_firestore/cloud_firestore.dart';

enum LimitPeriod { daily, weekly, monthly, manual }

LimitPeriod limitPeriodFromString(String? raw) {
  switch (raw) {
    case 'daily':
      return LimitPeriod.daily;
    case 'weekly':
      return LimitPeriod.weekly;
    case 'monthly':
      return LimitPeriod.monthly;
    case 'manual':
    default:
      return LimitPeriod.manual;
  }
}

String limitPeriodLabel(LimitPeriod p) {
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

/// Aligned period boundaries:
/// - daily   → today's local 00:00
/// - weekly  → most recent Sunday 00:00 (Saudi convention)
/// - monthly → 1st of this month, 00:00
/// - manual  → epoch (never auto-resets)
DateTime currentPeriodStart(LimitPeriod period, DateTime now) {
  switch (period) {
    case LimitPeriod.daily:
      return DateTime(now.year, now.month, now.day);
    case LimitPeriod.weekly:
      // DateTime.weekday: Mon=1..Sun=7. We want most-recent Sunday.
      final daysSinceSunday = now.weekday % 7; // Sun→0, Mon→1, ..., Sat→6
      return DateTime(now.year, now.month, now.day - daysSinceSunday);
    case LimitPeriod.monthly:
      return DateTime(now.year, now.month, 1);
    case LimitPeriod.manual:
      return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class FamilyWalletMember {
  final String userId;
  final double? limit;
  final LimitPeriod period;
  final double spentInPeriod;
  final DateTime periodStartedAt;

  const FamilyWalletMember({
    required this.userId,
    required this.limit,
    required this.period,
    required this.spentInPeriod,
    required this.periodStartedAt,
  });

  /// Spent this period, accounting for an elapsed period that hasn't been
  /// written-back yet. Used for UI progress bars.
  double effectiveSpent(DateTime now) {
    final boundary = currentPeriodStart(period, now);
    if (periodStartedAt.isBefore(boundary)) return 0.0;
    return spentInPeriod;
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'limit': limit,
        'period': period.name,
        'spentInPeriod': spentInPeriod,
        'periodStartedAt': Timestamp.fromDate(periodStartedAt),
      };

  factory FamilyWalletMember.fromMap(Map<String, dynamic> map) {
    final rawLimit = map['limit'];
    final rawSpent = map['spentInPeriod'];
    final rawStarted = map['periodStartedAt'];

    DateTime started;
    if (rawStarted is Timestamp) {
      started = rawStarted.toDate();
    } else if (rawStarted is DateTime) {
      started = rawStarted;
    } else {
      started = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return FamilyWalletMember(
      userId: (map['userId'] ?? '').toString(),
      limit: rawLimit is num ? rawLimit.toDouble() : null,
      period: limitPeriodFromString(map['period']?.toString()),
      spentInPeriod:
          rawSpent is num ? rawSpent.toDouble() : 0.0,
      periodStartedAt: started,
    );
  }
}
