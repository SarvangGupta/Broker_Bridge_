import 'requirement_model.dart';

/// Buyer-facing status buckets shown as summary cards and filter chips.
enum RequirementStatusBucket {
  open('Open'),
  inNegotiation('In Negotiation'),
  proposalReceived('Proposal Received'),
  confirmed('Confirmed'),
  completed('Completed');

  final String label;
  const RequirementStatusBucket(this.label);
}

/// Maps a backend requirement status onto a buyer-facing bucket.
///
/// Backend statuses seen in the platform: Open, Active, Matching,
/// In Negotiation, Allocated, Partially Fulfilled, Fulfilled, Cancelled.
/// Cancelled (and any unknown status) returns null: it counts toward "All"
/// but no bucket, so nothing is double-counted.
RequirementStatusBucket? statusBucketOf(String status) {
  final s = status.trim().toLowerCase();
  if (s.contains('cancel') || s.contains('reject')) return null;
  if (s.contains('propos') || s.contains('offer')) {
    return RequirementStatusBucket.proposalReceived;
  }
  if (s.contains('negotiat')) return RequirementStatusBucket.inNegotiation;
  if (s.contains('partially') ||
      s.contains('allocat') ||
      s.contains('confirm')) {
    return RequirementStatusBucket.confirmed;
  }
  if (s.contains('fulfil') || s.contains('complet') || s.contains('closed')) {
    return RequirementStatusBucket.completed;
  }
  if (s == 'open' || s == 'active' || s == 'matching') {
    return RequirementStatusBucket.open;
  }
  return null;
}

/// Requirements in a terminal state never count as overdue.
bool isDeadlineExempt(BuyerRequirement r) {
  final s = r.status.toLowerCase();
  return statusBucketOf(r.status) == RequirementStatusBucket.completed ||
      s.contains('cancel') ||
      s.contains('reject');
}

enum DeliveryGroup { overdue, dueSoon, upcoming, dateNotSet }

enum RequirementSort { earliestDelivery, latestDelivery, newestPosted }

enum DeliveryDateFilter { all, overdue, due7, due30, custom }

DateTime _day(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Whole calendar days from [today] until the delivery date, in local time.
/// Negative when the deadline has passed.
int daysUntilDelivery(BuyerRequirement r, DateTime today) {
  return _day(r.targetDate).difference(_day(today)).inDays;
}

DeliveryGroup deliveryGroupOf(BuyerRequirement r, DateTime today) {
  if (!r.hasTargetDate) return DeliveryGroup.dateNotSet;
  final days = daysUntilDelivery(r, today);
  if (days < 0) {
    return isDeadlineExempt(r) ? DeliveryGroup.upcoming : DeliveryGroup.overdue;
  }
  if (days <= 7) return DeliveryGroup.dueSoon;
  return DeliveryGroup.upcoming;
}

class RequirementListQuery {
  final RequirementStatusBucket? status;
  final String search;
  final RequirementSort sort;
  final DeliveryDateFilter dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;

  const RequirementListQuery({
    this.status,
    this.search = '',
    this.sort = RequirementSort.earliestDelivery,
    this.dateFilter = DeliveryDateFilter.all,
    this.customStart,
    this.customEnd,
  });

  bool get isDefault =>
      status == null &&
      search.trim().isEmpty &&
      sort == RequirementSort.earliestDelivery &&
      dateFilter == DeliveryDateFilter.all;
}

/// Counts per bucket over [all]; the total is `all.length`.
Map<RequirementStatusBucket, int> bucketCounts(List<BuyerRequirement> all) {
  final counts = {for (final b in RequirementStatusBucket.values) b: 0};
  for (final r in all) {
    final b = statusBucketOf(r.status);
    if (b != null) counts[b] = counts[b]! + 1;
  }
  return counts;
}

bool _matchesDate(BuyerRequirement r, RequirementListQuery q, DateTime today) {
  switch (q.dateFilter) {
    case DeliveryDateFilter.all:
      return true;
    case DeliveryDateFilter.overdue:
      return deliveryGroupOf(r, today) == DeliveryGroup.overdue;
    case DeliveryDateFilter.due7:
    case DeliveryDateFilter.due30:
      if (!r.hasTargetDate) return false;
      final days = daysUntilDelivery(r, today);
      final limit = q.dateFilter == DeliveryDateFilter.due7 ? 7 : 30;
      return days >= 0 && days <= limit;
    case DeliveryDateFilter.custom:
      if (!r.hasTargetDate || q.customStart == null || q.customEnd == null) {
        return q.customStart == null;
      }
      final d = _day(r.targetDate);
      return !d.isBefore(_day(q.customStart!)) && !d.isAfter(_day(q.customEnd!));
  }
}

/// Applies status, search and date filters, then sorts.
List<BuyerRequirement> applyRequirementQuery(
  List<BuyerRequirement> all,
  RequirementListQuery q,
  DateTime today,
) {
  final term = q.search.trim().toLowerCase();
  final result = all.where((r) {
    if (q.status != null && statusBucketOf(r.status) != q.status) return false;
    if (term.isNotEmpty &&
        !r.commodityName.toLowerCase().contains(term) &&
        !r.id.toLowerCase().contains(term)) {
      return false;
    }
    return _matchesDate(r, q, today);
  }).toList();

  int byDate(BuyerRequirement a, BuyerRequirement b) {
    if (a.hasTargetDate != b.hasTargetDate) return a.hasTargetDate ? -1 : 1;
    return a.targetDate.compareTo(b.targetDate);
  }

  switch (q.sort) {
    case RequirementSort.earliestDelivery:
      result.sort(byDate);
    case RequirementSort.latestDelivery:
      result.sort((a, b) {
        if (a.hasTargetDate != b.hasTargetDate) return a.hasTargetDate ? -1 : 1;
        return b.targetDate.compareTo(a.targetDate);
      });
    case RequirementSort.newestPosted:
      result.sort((a, b) {
        final ac = a.createdAt, bc = b.createdAt;
        if (ac == null && bc == null) return byDate(a, b);
        if (ac == null) return 1;
        if (bc == null) return -1;
        return bc.compareTo(ac);
      });
  }
  return result;
}

/// Groups an already-sorted list into delivery sections, preserving order.
Map<DeliveryGroup, List<BuyerRequirement>> groupByDelivery(
  List<BuyerRequirement> sorted,
  DateTime today,
) {
  final groups = {for (final g in DeliveryGroup.values) g: <BuyerRequirement>[]};
  for (final r in sorted) {
    groups[deliveryGroupOf(r, today)]!.add(r);
  }
  return groups;
}
