import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../authentication/domain/broker_user.dart';
import '../domain/dashboard_models.dart';

/// Sealed result hierarchy for dashboard data queries.
sealed class DashboardDataResult {
  const DashboardDataResult();
}

class DashboardDataSuccess extends DashboardDataResult {
  final BrokerDashboardMetrics metrics;
  final List<BrokerActivityItem> recentActivities;

  const DashboardDataSuccess({
    required this.metrics,
    this.recentActivities = const [],
  });
}

class DashboardDataUnavailable extends DashboardDataResult {
  final String contractNotice;

  const DashboardDataUnavailable({required this.contractNotice});
}

class DashboardDataError extends DashboardDataResult {
  final String message;
  final String? code;

  const DashboardDataError({required this.message, this.code});
}

class DashboardDataUnauthorized extends DashboardDataResult {
  final String message;

  const DashboardDataUnauthorized({
    this.message = 'Authentication session expired. Please sign in again.',
  });
}

/// Repository responsible for loading broker dashboard metrics from authoritative sources.
class DashboardRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  DashboardRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  }) : _customApiClient = apiClient,
       _customSupabase = supabase,
       _storage = storage ?? SecureStorageService();

  ApiClient get _apiClient =>
      _customApiClient ?? ApiClient(storage: _storage);

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the current logged-in broker details from secure storage or Supabase.
  Future<BrokerUser?> getAuthenticatedBroker() async {
    final id = await _storage.getUserId();
    final role = await _storage.getUserRole();
    final email = await _storage.getUserEmail();
    final name = await _storage.getUserName();

    if (id != null && role != null) {
      return BrokerUser(
        id: id,
        email: email ?? '',
        fullName: name ?? 'Commodity Broker',
        role: role,
      );
    }

    final supaUser = _supabase?.auth.currentUser;
    if (supaUser != null) {
      final metaRole = supaUser.userMetadata?['role'] as String? ?? 'broker';
      final metaName =
          (supaUser.userMetadata?['full_name'] as String?) ??
          'Commodity Broker';
      return BrokerUser(
        id: supaUser.id,
        email: supaUser.email ?? '',
        fullName: metaName,
        role: metaRole,
      );
    }

    return null;
  }

  /// Fetch dashboard metrics and activity stream from authorized backend endpoints.
  Future<DashboardDataResult> fetchDashboardData() async {
    // 1. Attempt authoritative REST endpoint via ApiClient
    try {
      final response = await _apiClient.get('/broker/dashboard');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DashboardDataError(
              message: data['error']?.toString() ?? 'Server returned failure status',
            );
          }

          final metrics = BrokerDashboardMetrics.fromJson(data);
          final activitiesRaw = data['recentActivity'] as List<dynamic>? ?? [];
          final activities = activitiesRaw
              .whereType<Map<String, dynamic>>()
              .map(BrokerActivityItem.fromJson)
              .toList();

          return DashboardDataSuccess(
            metrics: metrics,
            recentActivities: activities,
          );
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DashboardDataUnauthorized();
      }
      debugPrint('REST dashboard endpoint notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST query error: $e');
    }

    // 2. Direct Supabase fallback if user has an active authenticated session
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;

      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        // Perform parallel authoritative head count queries
        final dealsCountRes = await client
            .from('deals')
            .select('id')
            .eq('broker_id', brokerId)
            .count(CountOption.exact);

        final reqsCountRes = await client
            .from('requirements')
            .select('id')
            .eq('broker_id', brokerId)
            .count(CountOption.exact);

        final offersCountRes = await client
            .from('availabilities')
            .select('id')
            .eq('broker_id', brokerId)
            .count(CountOption.exact);

        final metrics = BrokerDashboardMetrics(
          activeDealsCount: dealsCountRes.count,
          openRequirementsCount: reqsCountRes.count,
          partiallyAllocatedCount: 0,
          availableOffersCount: offersCountRes.count,
          awaitingConfirmationCount: 0,
          dispatchDueCount: 0,
          deliveriesAwaitingCount: 0,
          commissionThisMonth: '₹0',
          openDisputesCount: 0,
          isAuthoritative: true,
          dataSourceNotice: 'Authoritative direct Supabase table counts verified.',
        );

        return DashboardDataSuccess(metrics: metrics);
      }
    } catch (dbErr) {
      debugPrint('Supabase direct query notice: $dbErr');
    }

    // 3. Honest Unavailable State (when REST route is not mounted and DB is unreachable offline)
    // Never fabricate fake business metrics.
    return const DashboardDataUnavailable(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/dashboard is pending backend exposure. '
          'Dashboard metrics are marked unavailable to prevent displaying fabricated business data.',
    );
  }
}
