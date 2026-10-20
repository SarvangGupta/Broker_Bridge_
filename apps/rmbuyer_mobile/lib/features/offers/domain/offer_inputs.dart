/// Input parameters for submitting a commercial counter-offer.
/// Strict validation: price and quantity must be positive.
class CounterOfferInput {
  final String proposalId;
  final int expectedVersionNumber;
  final double counterPrice;
  final double counterQuantity;
  final String? deliveryDate;
  final String? buyerNotes;

  const CounterOfferInput({
    required this.proposalId,
    required this.expectedVersionNumber,
    required this.counterPrice,
    required this.counterQuantity,
    this.deliveryDate,
    this.buyerNotes,
  });

  /// Client-side validation ensuring commercial parameters are strictly positive.
  String? validate() {
    if (proposalId.trim().isEmpty) {
      return 'Proposal ID is required.';
    }
    if (expectedVersionNumber <= 0) {
      return 'Invalid version number.';
    }
    if (counterPrice <= 0) {
      return 'Counter rate must be greater than zero.';
    }
    if (counterQuantity <= 0) {
      return 'Counter quantity must be greater than zero.';
    }
    return null;
  }
}

/// Input parameters for accepting a commercial offer.
class AcceptOfferInput {
  final String proposalId;
  final int expectedVersionNumber;

  const AcceptOfferInput({
    required this.proposalId,
    required this.expectedVersionNumber,
  });

  String? validate() {
    if (proposalId.trim().isEmpty) return 'Proposal ID is required.';
    if (expectedVersionNumber <= 0) return 'Invalid version number.';
    return null;
  }
}

/// Input parameters for rejecting a commercial offer with mandatory commercial reason.
class RejectOfferInput {
  final String proposalId;
  final int expectedVersionNumber;
  final String reason;
  final String? notes;

  const RejectOfferInput({
    required this.proposalId,
    required this.expectedVersionNumber,
    required this.reason,
    this.notes,
  });

  String? validate() {
    if (proposalId.trim().isEmpty) return 'Proposal ID is required.';
    if (expectedVersionNumber <= 0) return 'Invalid version number.';
    if (reason.trim().isEmpty) return 'A rejection reason is required.';
    return null;
  }
}
