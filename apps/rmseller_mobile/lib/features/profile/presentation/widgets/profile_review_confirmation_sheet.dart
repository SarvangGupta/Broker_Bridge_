import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/seller_profile_model.dart';
import '../profile_strings.dart';

/// Item representing a single field comparison between current profile and proposed changes.
class ProfileDiffItem {
  final String fieldName;
  final String currentValue;
  final String proposedValue;
  final bool isChanged;
  final bool isSensitive;
  final bool isHighImpact;

  const ProfileDiffItem({
    required this.fieldName,
    required this.currentValue,
    required this.proposedValue,
    required this.isChanged,
    this.isSensitive = false,
    this.isHighImpact = false,
  });
}

/// Modal bottom sheet enforcing the mandatory explicit confirmation workflow.
/// STRICT INVARIANT:
/// - No database write occurs before the seller taps "Confirm and Save".
/// - Dismissal, Back, or Cancel discards without saving.
class ProfileReviewConfirmationSheet extends StatelessWidget {
  final SellerProfileModel currentProfile;
  final SellerProfileModel proposedProfile;
  final bool isInvoiceAssisted;
  final bool isChequeAssisted;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ProfileStrings? strings;

  const ProfileReviewConfirmationSheet({
    super.key,
    required this.currentProfile,
    required this.proposedProfile,
    this.isInvoiceAssisted = false,
    this.isChequeAssisted = false,
    required this.onConfirm,
    required this.onCancel,
    this.strings,
  });

  List<ProfileDiffItem> _computeDiffs(ProfileStrings s) {
    final diffs = <ProfileDiffItem>[];

    void addDiff(String name, String current, String proposed, {bool isSensitive = false, bool isHighImpact = false}) {
      final c = current.trim();
      final p = proposed.trim();
      diffs.add(
        ProfileDiffItem(
          fieldName: name,
          currentValue: c.isNotEmpty ? c : s.notProvided,
          proposedValue: p.isNotEmpty ? p : s.notProvided,
          isChanged: c != p,
          isSensitive: isSensitive,
          isHighImpact: isHighImpact,
        ),
      );
    }

    addDiff(s.fullName, currentProfile.fullName, proposedProfile.fullName);
    addDiff(s.mobileNumber, currentProfile.mobile, proposedProfile.mobile);
    addDiff(s.businessName, currentProfile.companyName, proposedProfile.companyName, isHighImpact: true);
    if (proposedProfile.businessIdentifier.isNotEmpty && proposedProfile.businessIdentifier != proposedProfile.companyName) {
      addDiff('Business Identifier', currentProfile.businessIdentifier, proposedProfile.businessIdentifier, isHighImpact: true);
    }
    if (proposedProfile.versionIdentifier.isNotEmpty) {
      addDiff('Version Identifier', currentProfile.versionIdentifier, proposedProfile.versionIdentifier);
    }
    addDiff(s.gstinLabel, currentProfile.companyGst, proposedProfile.companyGst, isHighImpact: true);
    addDiff(s.corporateOfficeHqAddress, currentProfile.officeAddress, proposedProfile.officeAddress);
    addDiff(s.locationNameLabel, currentProfile.businessLocation.name, proposedProfile.businessLocation.name);
    addDiff(s.streetAddressLabel, currentProfile.businessLocation.addressLine, proposedProfile.businessLocation.addressLine);
    addDiff('${s.districtLabel} & ${s.stateLabel}',
        '${currentProfile.businessLocation.districtName}, ${currentProfile.businessLocation.stateName}',
        '${proposedProfile.businessLocation.districtName}, ${proposedProfile.businessLocation.stateName}');
    addDiff(s.pinCodeLabel, currentProfile.businessLocation.pinCode, proposedProfile.businessLocation.pinCode);

    // Bank Details
    final currBank = currentProfile.bankDetails;
    final propBank = proposedProfile.bankDetails;
    addDiff(s.accountHolderName, currBank.accountHolderName, propBank.accountHolderName, isSensitive: true);
    addDiff(s.bankName, currBank.bankName, propBank.bankName, isSensitive: true);
    addDiff(s.accountNumber, currBank.maskedAccountNumber, propBank.maskedAccountNumber, isSensitive: true, isHighImpact: true);
    addDiff(s.ifscCode, currBank.ifscCode, propBank.ifscCode, isSensitive: true, isHighImpact: true);
    if (propBank.branchName.isNotEmpty || currBank.branchName.isNotEmpty) {
      addDiff(s.branchNameOptional, currBank.branchName, propBank.branchName, isSensitive: true);
    }
    if (propBank.micrCode.isNotEmpty || currBank.micrCode.isNotEmpty) {
      addDiff(s.micrCode, currBank.micrCode, propBank.micrCode, isSensitive: true);
    }

    // Commodity Expertise
    final currExpertise = currentProfile.expertiseCommodityNames.join(', ');
    final propExpertise = proposedProfile.expertiseCommodityNames.join(', ');
    if (currExpertise.isNotEmpty || propExpertise.isNotEmpty) {
      addDiff(s.myCommodityExpertiseTitle, currExpertise, propExpertise);
    }

    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    final s = strings ?? ProfileStrings.of(context);
    final diffs = _computeDiffs(s);
    final changedDiffs = diffs.where((d) => d.isChanged).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.fileCheck2, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.reviewExtractedDetails,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          isInvoiceAssisted || isChequeAssisted
                              ? (s.isHindi
                                  ? (isChequeAssisted
                                      ? 'चेक से निकाले गए बैंक विवरण के लिए स्पष्ट पुष्टि आवश्यक है।'
                                      : 'बिल से निकाले गए विवरण के लिए स्पष्ट पुष्टि आवश्यक है।')
                                  : (isChequeAssisted
                                      ? 'Cheque-extracted bank details require explicit confirmation'
                                      : 'Invoice-assisted updates require explicit confirmation'))
                              : s.confirmationSubtitle,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close_confirmation_sheet'),
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      onCancel();
                    },
                  ),
                ],
              ),
            ),

            // Summary Notice
            if (isInvoiceAssisted)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, size: 16, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.isHindi
                            ? 'बिल से निकाले गए सुझाव आपकी पुष्टि तक असत्यापित हैं। बैंक विवरण भी व्यापार सत्यापन तक असत्यापित रहते हैं।'
                            : 'Extracted suggestions are unverified until confirmed by you. Bank details remain unverified until settlement verification.',
                        style: const TextStyle(fontSize: 11, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),

            // Change count banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      '${changedDiffs.length} ${s.isHindi ? 'फ़ील्ड संशोधित' : 'field(s) modified'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '${s.previousValueColumn} vs ${s.newValueColumn}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),

            // Diff List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: diffs.length,
                itemBuilder: (context, index) {
                  final item = diffs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      borderColor: item.isChanged
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.fieldName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              if (item.isChanged)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.isHindi ? 'परिवर्तित' : 'CHANGED',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                )
                              else
                                Text(
                                  s.isHindi ? 'अपरिवर्तित' : 'Unchanged',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Current
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.previousValueColumn, style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight)),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.currentValue,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: item.isChanged ? Colors.grey.shade600 : AppColors.textPrimaryLight,
                                          decoration: item.isChanged ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.textMutedLight),
                              const SizedBox(width: 8),
                              // Proposed
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: item.isChanged
                                        ? AppColors.primaryContainer.withValues(alpha: 0.25)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.newValueColumn, style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight)),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.proposedValue,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: item.isChanged ? FontWeight.w700 : FontWeight.normal,
                                          color: item.isChanged ? AppColors.primary : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ],
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
              ),
            ),

            // Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cancel_confirmation_button'),
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      child: Text(s.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      key: const Key('confirm_and_save_button'),
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: Text(
                        s.confirmAndSave,
                        softWrap: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
