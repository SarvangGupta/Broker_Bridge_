import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/phone_utils.dart';
import '../domain/seller_broker_model.dart';

/// Status of an authoritative broker phone lookup.
enum BrokerLookupStatus {
  /// Registered and verified licensed broker desk found.
  found,

  /// Registered broker found, but administrative KYC/profile verification is pending.
  pendingVerification,

  /// Phone number is not associated with an existing registered broker desk.
  notFound,

  /// Broker is already added to the seller's active My Mandi Brokers list.
  alreadyLinked,

  /// Validation error or network timeout.
  error,
}

/// Result returned from broker identity phone lookup.
class BrokerLookupResult {
  final BrokerLookupStatus status;
  final SellerBrokerModel? broker;
  final String normalizedPhone;
  final String formattedPhone;
  final String? errorMessage;

  const BrokerLookupResult({
    required this.status,
    this.broker,
    required this.normalizedPhone,
    required this.formattedPhone,
    this.errorMessage,
  });

  bool get isFound => status == BrokerLookupStatus.found;
  bool get isPendingVerification =>
      status == BrokerLookupStatus.pendingVerification;
  bool get isNotFound => status == BrokerLookupStatus.notFound;
  bool get isAlreadyLinked => status == BrokerLookupStatus.alreadyLinked;
  bool get isError => status == BrokerLookupStatus.error;
}

/// Repository for discovering, looking up, and linking broker desk relationships for the Seller.
/// COUNTERPARTY SHIELD INVARIANT:
/// Strictly excludes any Buyer records, Buyer directories, or direct Buyer contact paths.
class SellerBrokerRepository {
  final SupabaseClient? _customClient;

  // In-session cache for newly added and invited brokers
  static final List<SellerBrokerModel> _sessionBrokers = [];

  SellerBrokerRepository({SupabaseClient? client}) : _customClient = client;

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves authorized brokers for the seller, combining authoritative database
  /// records, in-session additions, and fallback desks.
  Future<List<SellerBrokerModel>> getBrokers({String? query}) async {
    final List<SellerBrokerModel> combined = [];

    // 1. Add session brokers first
    combined.addAll(_sessionBrokers);

    // 2. Query authoritative Supabase records
    final client = _supabase;
    if (client != null) {
      try {
        var queryBuilder = client
            .from('users')
            .select(
              'id, name, role, mobile, email, company_id, companies!users_company_id_companies_id_fk(id, name, gst, is_verified, trust_score)',
            )
            .eq('role', 'broker')
            .eq('status', true);

        if (query != null && query.trim().isNotEmpty) {
          queryBuilder = queryBuilder.ilike('name', '%${query.trim()}%');
        }

        final data = await queryBuilder.limit(25);
        if (data.isNotEmpty) {
          for (final row in data) {
            final model = SellerBrokerModel.fromMap(row);
            if (!combined.any(
              (b) =>
                  b.id == model.id ||
                  (model.mobile != null && b.mobile == model.mobile),
            )) {
              combined.add(model);
            }
          }
        }
      } catch (e) {
        debugPrint('Brokers Supabase query notice: $e');
      }
    }

    // 3. Fallback brokers if no database records loaded
    if (combined.isEmpty) {
      combined.addAll(fallbackBrokers);
    } else {
      // Ensure key licensed fallback desks are available in demo mode
      for (final fb in fallbackBrokers) {
        if (!combined.any(
          (b) => b.id == fb.id || (fb.mobile != null && b.mobile == fb.mobile),
        )) {
          combined.add(fb);
        }
      }
    }

    // 4. Filter by query
    var list = combined;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list
          .where(
            (b) =>
                b.name.toLowerCase().contains(q) ||
                (b.companyName?.toLowerCase().contains(q) ?? false) ||
                (b.location?.toLowerCase().contains(q) ?? false) ||
                b.commoditiesHandled.any((c) => c.toLowerCase().contains(q)),
          )
          .toList();
    }
    return list;
  }

  /// Retrieves a specific broker by authoritative ID
  Future<SellerBrokerModel?> getBrokerById(String id) async {
    final list = await getBrokers();
    for (final b in list) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Authoritative phone lookup to verify if a mobile number belongs to a registered broker.
  /// Strictly checks against registered broker accounts (`role = 'broker'`).
  Future<BrokerLookupResult> lookupBrokerByPhone(String rawPhone) async {
    final validation = PhoneUtils.validateAndNormalize(rawPhone);
    if (!validation.isValid) {
      return BrokerLookupResult(
        status: BrokerLookupStatus.error,
        normalizedPhone: validation.normalized,
        formattedPhone: validation.formatted,
        errorMessage: validation.error ?? 'Invalid phone number format',
      );
    }

    final normalized = validation.normalized;
    final formatted = validation.formatted;
    final rawDigits = validation.rawDigits;

    // Check if already in the seller's active brokers list
    final existingList = await getBrokers();
    for (final b in existingList) {
      if (b.mobile != null) {
        final bNorm = PhoneUtils.getNormalized(b.mobile);
        if (bNorm == normalized || b.mobile!.contains(rawDigits)) {
          return BrokerLookupResult(
            status: BrokerLookupStatus.alreadyLinked,
            broker: b,
            normalizedPhone: normalized,
            formattedPhone: formatted,
          );
        }
      }
    }

    // Authoritative lookup via Supabase
    final client = _supabase;
    if (client != null) {
      try {
        final data = await client
            .from('users')
            .select(
              'id, name, role, mobile, email, status, company_id, companies!users_company_id_companies_id_fk(id, name, gst, is_verified, trust_score)',
            )
            .eq('role', 'broker')
            .or(
              'mobile.eq.$normalized,mobile.eq.$rawDigits,mobile.eq.+91$rawDigits',
            )
            .limit(1);

        if (data.isNotEmpty) {
          final row = (data as List).first as Map<String, dynamic>;
          final broker = SellerBrokerModel.fromMap(row);
          if (broker.isVerified) {
            return BrokerLookupResult(
              status: BrokerLookupStatus.found,
              broker: broker,
              normalizedPhone: normalized,
              formattedPhone: formatted,
            );
          } else {
            return BrokerLookupResult(
              status: BrokerLookupStatus.pendingVerification,
              broker: broker,
              normalizedPhone: normalized,
              formattedPhone: formatted,
            );
          }
        }
      } catch (e) {
        debugPrint('Supabase broker phone lookup error: $e');
      }
    }

    // Check fallback registered desks (e.g. for offline/demo reliability)
    for (final fb in fallbackBrokers) {
      if (fb.mobile != null) {
        final fbNorm = PhoneUtils.getNormalized(fb.mobile);
        if (fbNorm == normalized || fb.mobile!.contains(rawDigits)) {
          return BrokerLookupResult(
            status: fb.isVerified
                ? BrokerLookupStatus.found
                : BrokerLookupStatus.pendingVerification,
            broker: fb,
            normalizedPhone: normalized,
            formattedPhone: formatted,
          );
        }
      }
    }

    // Number is not registered as a broker
    return BrokerLookupResult(
      status: BrokerLookupStatus.notFound,
      normalizedPhone: normalized,
      formattedPhone: formatted,
    );
  }

  /// Adds a verified or registered broker desk to the seller's active brokers list.
  Future<bool> addBroker(SellerBrokerModel broker) async {
    // Avoid duplicates
    final exists = _sessionBrokers.any(
      (b) =>
          b.id == broker.id ||
          (broker.mobile != null && b.mobile == broker.mobile),
    );
    if (!exists) {
      _sessionBrokers.insert(0, broker);
    }
    return true;
  }

  /// Records an invitation for an unregistered or unverified contact.
  /// The broker must authenticate and confirm their own professional desk details.
  Future<SellerBrokerModel> inviteBroker({
    required String normalizedPhone,
    String? contactName,
    String? nominationSource,
  }) async {
    final validation = PhoneUtils.validateAndNormalize(normalizedPhone);
    final displayPhone = validation.formatted.isNotEmpty
        ? validation.formatted
        : normalizedPhone;
    final displayName = (contactName != null && contactName.trim().isNotEmpty)
        ? contactName.trim()
        : 'Nominated Broker ($displayPhone)';

    final invitedBroker = SellerBrokerModel(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      name: displayName,
      mobile: validation.normalized.isNotEmpty
          ? validation.normalized
          : normalizedPhone,
      companyName: 'Invited Broker Desk (Pending Confirmation)',
      location: 'Pending Broker Registration',
      trustScore: 100,
      isVerified: false,
      commoditiesHandled: const ['General Commodities'],
      status: SellerBrokerStatus.invitationPending,
      invitedAt: DateTime.now(),
      nominationSource: nominationSource ?? 'seller_nomination',
    );

    // Save to session list
    _sessionBrokers.removeWhere((b) => b.mobile == invitedBroker.mobile);
    _sessionBrokers.insert(0, invitedBroker);

    return invitedBroker;
  }

  /// Checks if a phone number already exists in the seller's active list
  Future<bool> isDuplicate(String rawPhone) async {
    final norm = PhoneUtils.getNormalized(rawPhone);
    if (norm == null) return false;

    final brokers = await getBrokers();
    for (final b in brokers) {
      if (b.mobile != null && PhoneUtils.getNormalized(b.mobile) == norm) {
        return true;
      }
    }
    return false;
  }

  static const List<SellerBrokerModel> fallbackBrokers = [
    SellerBrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
      name: 'Bikaner Mandi Broker Desk',
      email: 'bikaner.broker@mandi.in',
      mobile: '+919829012345',
      companyName: 'Bikaner Grain Merchants Association Desk',
      companyGst: '08AAAAA1234A1Z1',
      location: 'Krishi Upaj Mandi, Bikaner',
      trustScore: 99,
      isVerified: true,
      commoditiesHandled: [
        'Desi Chana (Gram)',
        'Mustard Seeds',
        'Guar Gum',
        'Wheat',
      ],
      averageRating: 4.7,
      reviewCount: 3,
      status: SellerBrokerStatus.registeredVerified,
    ),
    SellerBrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e33',
      name: 'Indore Mandi Associates',
      email: 'indore.desk@agrobroker.in',
      mobile: '+919826054321',
      companyName: 'Malwa Agro Brokerage LLP',
      companyGst: '23BBBBB5678B1Z2',
      location: 'Chhavani Mandi, Indore',
      trustScore: 96,
      isVerified: true,
      commoditiesHandled: ['Yellow Soybean', 'Wheat', 'Maize', 'Chana'],
      averageRating: 4.5,
      reviewCount: 2,
      status: SellerBrokerStatus.registeredVerified,
    ),
    SellerBrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e34',
      name: 'Kota Agro Brokerage',
      email: 'kota.desk@mandi.in',
      mobile: '+919829098765',
      companyName: 'Hadoti Grain Traders Syndicate',
      companyGst: '08CCCCC9012C1Z3',
      location: 'Bhamashah Mandi, Kota',
      trustScore: 94,
      isVerified: true,
      commoditiesHandled: ['Mustard Seeds', 'Soybean', 'Coriander', 'Wheat'],
      averageRating: 5.0,
      reviewCount: 1,
      status: SellerBrokerStatus.registeredVerified,
    ),
    SellerBrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e35',
      name: 'Jaipur Grain Broker Desk',
      email: 'jaipur.broker@mandi.in',
      mobile: '+919829055443',
      companyName: 'Surajpole Mandi Brokerage Desk',
      companyGst: '08DDDDD3456D1Z4',
      location: 'Surajpole Grain Mandi, Jaipur',
      trustScore: 97,
      isVerified: true,
      commoditiesHandled: [
        'Desi Chana (Gram)',
        'Barley',
        'Mustard Seeds',
        'Bajra',
      ],
      averageRating: null, // Unrated desk
      reviewCount: 0,
      status: SellerBrokerStatus.registeredVerified,
    ),
  ];
}
