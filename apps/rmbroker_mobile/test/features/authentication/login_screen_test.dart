import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/theme/app_theme.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/auth_result.dart';
import 'package:rmbroker_mobile/features/authentication/presentation/login_screen.dart';

class MockFailingAuthRepository extends AuthRepository {
  final String errorMessage;
  MockFailingAuthRepository({required this.errorMessage});

  @override
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return AuthFailure(message: errorMessage, code: 'INVALID_CREDENTIALS');
  }
}

void main() {
  Widget buildTestableLoginScreen({AuthRepository? authRepository}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(authRepository: authRepository),
    );
  }

  group('LoginScreen Widget & Ergonomics Tests', () {
    testWidgets('renders brand badge, fiduciary notice, and inputs cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableLoginScreen());

      expect(find.text('BB'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('RMBroker is a broker desk'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In to Broker Desk'), findsOneWidget);
    });

    testWidgets('validates required email and password fields on submit', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableLoginScreen());

      final submitButton = find.text('Sign In to Broker Desk');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('validates email format and password length constraints', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableLoginScreen());

      final emailField = find.widgetWithText(TextFormField, '');
      // Enter invalid email
      await tester.enterText(emailField.first, 'invalidemail');
      // Enter short password
      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, '123');

      final submitButton = find.text('Sign In to Broker Desk');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('displays sanitized error banner when authentication fails', (
      tester,
    ) async {
      final mockRepo = MockFailingAuthRepository(
        errorMessage: 'Invalid email or password. Please verify your credentials and try again.',
      );

      await tester.pumpWidget(
        buildTestableLoginScreen(authRepository: mockRepo),
      );

      // Enter valid formats
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'broker@brokerbridge.com');
      await tester.enterText(textFields.last, 'wrongpass123');

      final submitButton = find.text('Sign In to Broker Desk');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Invalid email or password. Please verify your credentials and try again.',
        ),
        findsOneWidget,
      );
    });
  });
}
