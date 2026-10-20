import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';
import '../domain/auth_result.dart';

/// Splash screen rendering RMBuyer branding and performing session preflight.
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
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    // Artificial 1-second delay for smooth splash presentation
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    try {
      final status = await _authRepo.checkSession();
      if (!mounted) return;

      switch (status) {
        case SessionStatus.authenticated:
          final buyer = await _authRepo.getCurrentBuyer();
          if (buyer != null) {
            AppRouter.authNotifier.setAuthenticated(buyer);
          } else {
            AppRouter.authNotifier.setStatus(AuthStatus.authenticated);
          }
          if (mounted) context.go('/home');
          break;
        case SessionStatus.accessDenied:
          AppRouter.authNotifier.setAccessDenied(
            email: '',
            role: 'unauthorized',
            message: 'Your authenticated account lacks buyer procurement permissions.',
          );
          if (mounted) context.go('/access-denied');
          break;
        case SessionStatus.unauthenticated:
        case SessionStatus.expired:
          AppRouter.authNotifier.setUnauthenticated();
          if (mounted) context.go('/login');
          break;
      }
    } catch (_) {
      if (mounted) {
        AppRouter.authNotifier.setUnauthenticated();
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'RB',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppConfig.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppConfig.appTagline,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFCFD8DC),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
