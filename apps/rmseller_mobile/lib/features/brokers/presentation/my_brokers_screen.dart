import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/services/contact_picker_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/seller_broker_repository.dart';
import '../domain/seller_broker_model.dart';

class MyBrokersScreen extends StatefulWidget {
  const MyBrokersScreen({super.key});

  @override
  State<MyBrokersScreen> createState() => _MyBrokersScreenState();
}

class _MyBrokersScreenState extends State<MyBrokersScreen> {
  final SellerBrokerRepository _repository = SellerBrokerRepository();
  final ContactLauncherService _contactLauncher =
      const ContactLauncherService();
  final ContactPickerService _contactPicker = const ContactPickerService();

  bool _isLoading = true;
  String? _errorMessage;
  List<SellerBrokerModel> _brokers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBrokers();
  }

  Future<void> _fetchBrokers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getBrokers(query: _searchQuery);
      if (!mounted) return;
      setState(() {
        _brokers = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load verified mandi broker directory: $e';
        _isLoading = false;
      });
    }
  }

  /// Opens the Add Broker bottom sheet with clear options
  void _showAddBrokerOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.userPlus,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Mandi Broker',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Connect with registered brokers or invite a new broker desk.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Option 1: Select from Phone Contacts
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.contact,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Select from Phone Contacts',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Pick a broker directly from your mobile address book',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMutedLight,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handlePickFromContacts();
                  },
                ),

                const Divider(height: 1),

                // Option 2: Add Number Manually
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.edit3,
                      color: Colors.purple.shade700,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Add Number Manually',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Enter a 10-digit mobile number with +91 country standard',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMutedLight,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showManualEntryDialog();
                  },
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Handles privacy-preserving contact selection via system contact picker
  Future<void> _handlePickFromContacts() async {
    final result = await _contactPicker.pickContact();

    if (!mounted) return;

    if (result.isCancelled) {
      // User cancelled picker - do nothing
      return;
    }

    if (!result.isSuccess || result.contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to select contact.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final contact = result.contact!;
    final validation = PhoneUtils.validateAndNormalize(contact.phone);

    if (!validation.isValid) {
      _showInfoDialog(
        title: 'Unsupported Phone Number',
        icon: LucideIcons.alertTriangle,
        iconColor: Colors.amber.shade800,
        message:
            'The selected contact "${contact.name}" has an invalid phone number ("${contact.phone}").\n\n${validation.error ?? 'Please select a contact with a 10-digit Indian mobile number.'}',
      );
      return;
    }

    await _performBrokerLookup(
      contact.phone,
      contactName: contact.name,
      source: 'phone_contacts',
    );
  }

  /// Displays dialog for manually entering a broker's phone number
  void _showManualEntryDialog() {
    final phoneController = TextEditingController();
    String? inlineError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter Broker Mobile Number',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter the 10-digit mobile number for the broker desk. Indian mobile standards (+91) are enforced.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            '+91 (IN)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (_) {
                              if (inlineError != null) {
                                setModalState(() => inlineError = null);
                              }
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '98290 12345',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        inlineError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final raw = phoneController.text.trim();
                              final validation =
                                  PhoneUtils.validateAndNormalize(raw);
                              if (!validation.isValid) {
                                setModalState(() {
                                  inlineError =
                                      validation.error ??
                                      'Please enter a valid 10-digit number';
                                });
                                return;
                              }
                              Navigator.pop(ctx);
                              _performBrokerLookup(raw, source: 'manual_entry');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Verify & Add',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Authoritative broker lookup workflow
  Future<void> _performBrokerLookup(
    String rawPhone, {
    String? contactName,
    String? source,
  }) async {
    // Show loading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          elevation: 6,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
                SizedBox(width: 16),
                Text(
                  'Verifying broker desk on network...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await _repository.lookupBrokerByPhone(rawPhone);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

    switch (result.status) {
      case BrokerLookupStatus.alreadyLinked:
        _showInfoDialog(
          title: 'Broker Already Linked',
          icon: LucideIcons.checkCircle2,
          iconColor: AppColors.primary,
          message:
              '${result.broker?.name ?? result.formattedPhone} is already present in your My Mandi Brokers list.',
        );
        break;

      case BrokerLookupStatus.found:
        _showBrokerMatchSheet(result.broker!);
        break;

      case BrokerLookupStatus.pendingVerification:
        _showPendingVerificationSheet(result.broker!);
        break;

      case BrokerLookupStatus.notFound:
        _showInvitationSheet(
          result.normalizedPhone,
          result.formattedPhone,
          contactName: contactName,
          source: source,
        );
        break;

      case BrokerLookupStatus.error:
        _showRetryableErrorDialog(
          message: result.errorMessage ?? 'Unable to verify broker status.',
          onRetry: () => _performBrokerLookup(
            rawPhone,
            contactName: contactName,
            source: source,
          ),
        );
        break;
    }
  }

  /// Bottom sheet showing verified registered broker match
  void _showBrokerMatchSheet(SellerBrokerModel broker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.badgeCheck,
                        color: AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registered Broker Desk Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Authoritative license verified by platform administration',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              broker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.shieldCheck,
                                  size: 12,
                                  color: AppColors.secondaryDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${broker.trustScore}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        broker.companyName ?? 'Licensed Mandi Broker Desk',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 13,
                            color: AppColors.textMutedLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            broker.location ?? 'Mandi Trading Floor',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: broker.commoditiesHandled.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _repository.addBroker(broker);
                          await _fetchBrokers();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${broker.name} to your trusted Mandi Brokers.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add to My Brokers',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Sheet shown when registered broker is pending administrative verification
  void _showPendingVerificationSheet(SellerBrokerModel broker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.clock,
                        color: Colors.amber.shade800,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broker Verification Pending',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Administrative vetting is in progress',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.amber.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${broker.name} has registered on RMBroker, but platform administrative verification is currently pending. You can bookmark this desk now, but active trade allocations require verified status.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _repository.addBroker(broker);
                          await _fetchBrokers();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${broker.name} (Verification Pending).',
                              ),
                              backgroundColor: Colors.amber.shade800,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add Desk (Pending)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Invitation workflow for unregistered or unverified broker contacts.
  /// Strictly enforces broker self-verification: local phone contact is NEVER marked verified.
  void _showInvitationSheet(
    String normalizedPhone,
    String formattedPhone, {
    String? contactName,
    String? source,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.send,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Broker Not Registered Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contactName != null
                                ? '$contactName ($formattedPhone)'
                                : formattedPhone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.shieldAlert,
                            size: 14,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Broker Self-Verification Required',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This contact is not yet registered on RMBroker. Broker desks are invite-only and subject to platform administrative vetting.\n\nThe broker must confirm and maintain their own professional desk details. Invite them to register below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action 1: Invite via WhatsApp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final message =
                          'Hello ${contactName ?? 'Partner'}, I would like to add you as my trusted commodity broker on RMBroker. Please connect with RMBroker Platform Administration to verify your licensed broker desk: https://brokerbridge.in/login';
                      await _contactLauncher.launchWhatsApp(
                        normalizedPhone,
                        defaultMessage: message,
                      );
                      await _repository.inviteBroker(
                        normalizedPhone: normalizedPhone,
                        contactName: contactName,
                        nominationSource: source,
                      );
                      await _fetchBrokers();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invitation sent. Desk added as Pending Confirmation.',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(
                      LucideIcons.messageCircle,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Invite via WhatsApp',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action 2: Invite via Phone Dialler
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _contactLauncher.launchPhone(normalizedPhone);
                      await _repository.inviteBroker(
                        normalizedPhone: normalizedPhone,
                        contactName: contactName,
                        nominationSource: source,
                      );
                      await _fetchBrokers();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dialler launched. Desk added as Pending Confirmation.',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(
                      LucideIcons.phone,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Call Desk to Invite',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action 3: Cancel
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel without Inviting',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInfoDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showRetryableErrorDialog({
    required String message,
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertCircle, color: AppColors.error, size: 22),
            SizedBox(width: 10),
            Text(
              'Lookup Notice',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Retry Lookup',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Mandi Brokers'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _fetchBrokers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBrokerOptions,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.userPlus, size: 20),
        label: const Text(
          'Add Broker',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        tooltip: 'Add Broker',
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _fetchBrokers();
              },
              decoration: InputDecoration(
                hintText: 'Search brokers by name, mandi, or commodity...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _fetchBrokers();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator(
                    message: 'Loading licensed mandi brokers...',
                  )
                : _errorMessage != null
                ? AppErrorState(message: _errorMessage!, onRetry: _fetchBrokers)
                : _brokers.isEmpty
                ? AppEmptyState(
                    title: 'No Brokers Found',
                    message: _searchQuery.isNotEmpty
                        ? 'No mandi brokers match "$_searchQuery". Try searching for "Chana", "Soybean", or "Bikaner".'
                        : 'No verified mandi brokers currently listed for your region.',
                  )
                : RefreshIndicator(
                    onRefresh: _fetchBrokers,
                    color: AppColors.primary,
                    child: ListView.builder(
                      // Bottom padding to avoid FAB overlap
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                      itemCount: _brokers.length,
                      itemBuilder: (context, index) {
                        final broker = _brokers[index];
                        return _buildBrokerCard(context, broker);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required Color background,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactIcon({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: color.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: IconButton(
          key: key,
          icon: Icon(icon, size: 17, color: color),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
      ),
    );
  }

  Widget _buildBrokerCard(BuildContext context, SellerBrokerModel broker) {
    final statusBadges = <Widget>[
      if (broker.isRegisteredVerified)
        _buildBadge(
          label: 'Verified',
          icon: LucideIcons.badgeCheck,
          color: AppColors.success,
          background: AppColors.success.withValues(alpha: 0.1),
        )
      else if (broker.isPendingVerification)
        _buildBadge(
          label: 'Pending Verification',
          icon: LucideIcons.clock,
          color: Colors.amber.shade900,
          background: Colors.amber.shade100,
        )
      else if (broker.isInvitationPending) ...[
        _buildBadge(
          label: 'Invitation Pending',
          color: Colors.blue.shade800,
          background: Colors.blue.shade50,
        ),
        _buildBadge(
          label: 'Unregistered',
          color: AppColors.textMutedLight,
          background: Colors.grey.shade100,
        ),
      ],
      if (!broker.isInvitationPending) ...[
        _buildBadge(
          label: '${broker.trustScore}%',
          icon: LucideIcons.shieldCheck,
          color: AppColors.secondaryDark,
          background: AppColors.secondaryContainer,
        ),
        if (broker.hasRatings)
          _buildBadge(
            label:
                '${broker.averageRating!.toStringAsFixed(1)} (${broker.reviewCount})',
            icon: Icons.star,
            color: Colors.amber.shade900,
            background: Colors.amber.shade50,
          )
        else
          _buildBadge(
            label: 'Unrated',
            icon: Icons.star_border,
            color: AppColors.textMutedLight,
            background: Colors.grey.shade100,
          ),
      ],
    ];

    final contactButtons = <Widget>[
      if (broker.hasPhone)
        _buildContactIcon(
          key: Key('broker_call_${broker.id}'),
          icon: LucideIcons.phone,
          tooltip: broker.isInvitationPending ? 'Call Contact' : 'Call Desk',
          color: AppColors.primary,
          onPressed: () => _contactLauncher.launchPhone(broker.mobile),
        ),
      if (broker.hasWhatsApp)
        _buildContactIcon(
          key: Key('broker_whatsapp_${broker.id}'),
          icon: LucideIcons.messageCircle,
          tooltip: broker.isInvitationPending ? 'WhatsApp Invite' : 'WhatsApp',
          color: Colors.green.shade700,
          onPressed: () {
            if (broker.isInvitationPending) {
              final message =
                  'Hello ${broker.name}, I would like to add you as my trusted commodity broker on RMBroker. Please connect with RMBroker Platform Administration to verify your licensed broker desk: https://brokerbridge.in/login';
              _contactLauncher.launchWhatsApp(
                broker.mobile,
                defaultMessage: message,
              );
            } else {
              _contactLauncher.launchWhatsApp(
                broker.mobile,
                defaultMessage:
                    'Hello ${broker.name}, I have commodity lots ready for trade on RMSeller.',
              );
            }
          },
        ),
      if (!broker.isInvitationPending)
        _buildContactIcon(
          key: Key('broker_chat_${broker.id}'),
          icon: LucideIcons.messageSquare,
          tooltip: 'Broker Chat & Commission Terms',
          color: Colors.indigo.shade400,
          onPressed: () => context.push(
            '/communication/broker/${broker.id}',
            extra: broker,
          ),
        ),
    ];

    final location = [
      broker.location ?? 'Mandi Trading Floor',
      if (broker.companyName != null && broker.companyName!.isNotEmpty)
        broker.companyName!,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        onTap: () {
          if (!broker.isInvitationPending) {
            context.push('/brokers/${broker.id}', extra: broker);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: broker.isInvitationPending
                  ? Colors.blue.shade100
                  : AppColors.primaryContainer,
              child: Text(
                broker.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: broker.isInvitationPending
                      ? Colors.blue.shade800
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: name + verification, trust, rating
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        broker.name,
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ...statusBadges,
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Row 2: location, or invitation notice
                  if (broker.isInvitationPending)
                    Text(
                      'Nominated by you. Pending broker self-registration and profile confirmation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 13,
                          color: AppColors.textMutedLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),

                  // Row 3: commodity chips + icon-only contact actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: broker.isInvitationPending
                              ? const []
                              : broker.commoditiesHandled.map((c) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                      ...contactButtons,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

