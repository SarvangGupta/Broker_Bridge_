import 'package:flutter/foundation.dart';

/// Centralized application configuration for RMSeller.
/// Values can be overridden at compile-time using --dart-define:
/// flutter run --dart-define=API_BASE_URL=https://...
class AppConfig {
  const AppConfig._();

  static const String appName = 'RMSeller';
  static const String appDisplayName = 'RMSeller';
  static const String appVersion = '0.1.0';
  static const String appTagline = 'Enterprise Commodity Seller & Supply Desk';

  /// Supabase project configuration (public anon credentials)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://imztlkvkxzeaekxvmcfe.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltenRsa3ZreHplYWVreHZtY2ZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5MTgwNzksImV4cCI6MjEwMTQ5NDA3OX0.SmFwSY_ZKl97mfHeyYqakHE5r_Q02TFX1Eds_sBAp1o',
  );

  /// Next.js REST API Base URL
  /// For Android emulator use 10.0.2.2:3001, for USB reverse proxy use localhost:3001
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode
        ? 'http://localhost:3001/api/v1'
        : 'https://rmseller.example.com/api/v1',
  );

  /// Network timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Fiduciary disclaimer
  static const String fiduciaryNoticeEn =
      'Seller Notice: RMSeller is a commodity supply desk. All commercial negotiations, matching, and contract finalizations are strictly broker-mediated.';
  static const String fiduciaryNoticeHi =
      'विक्रेता सूचना: आरएमसेलर एक आपूर्ति मंच है। सभी व्यापार वार्ताएं, मिलान और अनुबंध अंतिमकरण केवल अधिकृत ब्रोकर डेस्क द्वारा मध्यस्थ होते हैं।';
}
