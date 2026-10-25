import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/buyer_profile_repository.dart';
import '../domain/buyer_profile.dart';

/// Profile & Settings hub opened from the top-right profile icon and the
/// Profile tab: a profile summary plus the settings the app supports end to end.
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final BuyerProfileRepository? repository;
  final AuthRepository? authRepository;

  const ProfileSettingsScreen({
    super.key,
    this.repository,
    this.authRepository,
  });

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final BuyerProfileRepository _repo;
  late final AuthRepository _authRepo;
  BuyerProfile? _profile;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerProfileRepository();
    _authRepo = widget.authRepository ?? AuthRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final profile = await _repo.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile summary load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openEditProfile() async {
    await context.push('/settings/profile');
    if (mounted) _load();
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          ctx.tr(Tr.signOutTitle),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          ctx.tr(Tr.signOutBody),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(Tr.commonCancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(ctx.tr(Tr.signOutConfirm)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authRepo.signOut();
      AppRouter.authNotifier.setUnauthenticated();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appSettingsProvider).languagePref;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr(Tr.titleProfileSettings))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummary(),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _tile(
                    key: const Key('settings-edit-profile'),
                    icon: LucideIcons.userPen,
                    title: context.tr(Tr.hubEditProfile),
                    subtitle: context.tr(Tr.hubEditProfileSub),
                    onTap: _openEditProfile,
                  ),
                  const Divider(height: 1),
                  _tile(
                    key: const Key('settings-language'),
                    icon: LucideIcons.languages,
                    title: context.tr(Tr.hubLanguage),
                    subtitle: language.displayName,
                    onTap: () => context.push('/settings/language'),
                  ),
                  const Divider(height: 1),
                  _tile(
                    key: const Key('settings-display'),
                    icon: LucideIcons.sunMoon,
                    title: context.tr(Tr.hubDisplay),
                    subtitle: context.tr(Tr.hubDisplaySub),
                    onTap: () => context.push('/settings/display'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: _tile(
                key: const Key('settings-sign-out'),
                icon: LucideIcons.logOut,
                title: context.tr(Tr.hubSignOut),
                color: AppColors.error,
                onTap: _handleSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_isLoading) {
      return const AppCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    final profile = _profile;
    if (_loadFailed || profile == null) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.cloudOff, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(Tr.profileLoadError),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
            TextButton(
              key: const Key('settings-profile-retry'),
              onPressed: _load,
              child: Text(context.tr(Tr.commonRetry)),
            ),
          ],
        ),
      );
    }

    final name = profile.name.isEmpty
        ? context.tr(Tr.commonNotProvided)
        : profile.name;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              profile.name.isNotEmpty
                  ? profile.name.characters.first.toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.email!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                if (profile.companyName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.companyName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required Key key,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final fg = color ?? AppColors.textPrimaryLight;
    // Own Material so ink splashes show above the card's background.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: key,
        minTileHeight: 56,
        leading: Icon(icon, size: 20, color: color ?? AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
        trailing: color == null
            ? const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMutedLight,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
