import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_repository.dart';
import '../domain/auth_result.dart';

/// Secure Buyer Portal login screen with email/password authentication
/// and role enforcement.
class LoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const LoginScreen({super.key, this.authRepository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = widget.authRepository ?? AuthRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both your work email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.signInWithPassword(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case AuthSuccess(:final user):
        AppRouter.authNotifier.setAuthenticated(user);
        context.go('/home');
        break;

      case AuthAccessDenied(:final email, :final role, :final message):
        AppRouter.authNotifier.setAccessDenied(
          email: email,
          role: role,
          message: message,
        );
        context.go(
          '/access-denied',
          extra: {
            'email': email,
            'role': role,
            'message': message,
          },
        );
        break;

      case AuthFailure(:final message):
        setState(() {
          _errorMessage = message;
        });
        break;
    }
  }

  void _fillBuyerDemoCredentials() {
    _emailController.text = 'buyer.procurement@brokerbridge.com';
    _passwordController.text = 'BuyerSecurePass2026!';
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header branding
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'RB',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Procurement Buyer Workstation Login',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Fiduciary notice banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppConfig.fiduciaryNoticeEn,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login card
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          controller: _emailController,
                          label: 'Work Email Address',
                          hint: 'buyer@company.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(LucideIcons.mail, size: 18),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: '••••••••••••',
                          obscureText: _obscurePassword,
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: 'Sign In to RMBuyer',
                          onPressed: _handleLogin,
                          isLoading: _isLoading,
                          icon: LucideIcons.logIn,
                        ),
                        const SizedBox(height: 14),

                        // Quick fill for testing
                        TextButton.icon(
                          onPressed: _fillBuyerDemoCredentials,
                          icon: const Icon(LucideIcons.sparkles, size: 16),
                          label: const Text(
                            'Fill Buyer Demo Credentials',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'RMBuyer Enterprise • Commodity Mandi Ecosystem v0.1.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMutedLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
