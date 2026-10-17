import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/errors/app_exceptions.dart';

void main() {
  group('AppException Tests', () {
    test('NetworkException produces structured code and message', () {
      const ex = NetworkException(message: 'Connection timed out');
      expect(ex.code, equals('NETWORK_ERROR'));
      expect(ex.message, equals('Connection timed out'));
      expect(ex.toString(), contains('NetworkException'));
    });

    test('UnauthorizedException produces session expired code', () {
      const ex = UnauthorizedException();
      expect(ex.code, equals('UNAUTHORIZED'));
      expect(ex.message, contains('session has expired'));
    });

    test('ForbiddenException produces access denied message', () {
      const ex = ForbiddenException();
      expect(ex.code, equals('FORBIDDEN'));
      expect(ex.message, contains('Broker role privileges required'));
    });

    test('ValidationException preserves details payload', () {
      const ex = ValidationException(
        message: 'Invalid quantity',
        details: {'field': 'quantity', 'error': 'Must be positive'},
      );
      expect(ex.code, equals('VALIDATION_ERROR'));
      expect(ex.details, isA<Map>());
      expect(ex.details['field'], equals('quantity'));
    });
  });
}
