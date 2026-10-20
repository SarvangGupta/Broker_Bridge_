import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../data/auth_repository.dart';
import '../domain/auth_result.dart';

/// App startup and session initialization screen.
class SplashScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const SplashScreen({super.key, this.authRepository});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = widget.authRepository ?? AuthRepository();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    try {
      final sessionStatus = await _authRepo.checkSession();
      if (!mounted) return;

      switch (sessionStatus) {
        case SessionStatus.authenticated:
          context.go('/work');
        case SessionStatus.accessDenied:
          context.go(
            '/access-denied',
            extra: {
              'email': '',
              'role': 'unauthorized',
              'message': 'Active session lacks broker desk authorization.',
            },
          );
        case SessionStatus.unauthenticated:
        case SessionStatus.expired:
          context.go('/login');
      }
    } catch (_) {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'BB',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RMBroker',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Commodity Mandi Broker Desk',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
