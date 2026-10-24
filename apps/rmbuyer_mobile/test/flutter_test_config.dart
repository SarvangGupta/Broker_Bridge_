import 'dart:async';
import 'dart:io';

import 'support/live_test_config.dart';
import 'support/network_guard.dart';

/// Applied by `flutter test` to every test file under `test/`.
/// Installs a fail-closed network guard so no test can reach the production backend.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = TestNetworkGuardOverrides(
    allowedHosts: LiveTestConfig.allowedHosts(),
  );
  await testMain();
}
