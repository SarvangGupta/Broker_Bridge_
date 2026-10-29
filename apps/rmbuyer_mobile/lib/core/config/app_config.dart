import 'package:flutter/foundation.dart';

/// Centralized application configuration for RMBuyer.
/// Values can be overridden at compile-time using --dart-define:
/// flutter run --dart-define=API_BASE_URL=https://...
class AppConfig {
  const AppConfig._();

  static const String appName = 'RMBuyer';
  static const String appDisplayName = 'RMBuyer';
  static const String appVersion = '0.1.0';
  static const String appTagline = 'Enterprise Commodity Buyer Portal';

  /// Supabase project configuration (public anon credentials)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://imztlkvkxzeaekxvmcfe.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltenRsa3ZreHplYWVreHZtY2ZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5MTgwNzksImV4cCI6MjEwMTQ5NDA3OX0.SmFwSY_ZKl97mfHeyYqakHE5r_Q02TFX1Eds_sBAp1o',
  );

  /// Production Supabase project ref. The GST verification backend (proposed
  /// migrations 0053/0054) is not applied there, so it must not be used with it.
  static const String productionProjectRef = 'imztlkvkxzeaekxvmcfe';

  /// Opt-in for the secure GST verification backend:
  /// `--dart-define=GST_VERIFICATION_BACKEND=true` with a NON-production
  /// SUPABASE_URL/SUPABASE_ANON_KEY. Ignored for the production project until
  /// the production rollout is approved and applied.
  static const bool gstVerificationBackendRequested = bool.fromEnvironment(
    'GST_VERIFICATION_BACKEND',
  );

  static bool get gstVerificationBackendEnabled =>
      gstVerificationBackendAllowed(
        requested: gstVerificationBackendRequested,
        supabaseUrl: supabaseUrl,
      );

  @visibleForTesting
  static bool gstVerificationBackendAllowed({
    required bool requested,
    required String supabaseUrl,
  }) => requested && !supabaseUrl.contains(productionProjectRef);

  /// Next.js REST API Base URL
  /// For Android emulator use 10.0.2.2:3001, for USB reverse proxy use localhost:3001
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode
        ? 'http://localhost:3001/api/v1'
        : 'https://rmbroker.example.com/api/v1',
  );

  /// Network timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Fiduciary disclaimer
  static const String fiduciaryNoticeEn =
      'Buyer Notice: RMBuyer is a buyer procurement workstation. All commodity negotiations and contract finalizations are strictly broker-mediated.';
  static const String fiduciaryNoticeHi =
      'क्रेता सूचना: आरएमबायर्स एक खरीद मंच है। सभी व्यापार वार्ताएं और सौदे ब्रोकर डेस्क द्वारा मध्यस्थ होते हैं।';
}
