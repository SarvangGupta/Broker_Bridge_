import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';
import '../../domain/gst_certificate_data.dart';
import '../controllers/contact_form_controller.dart';
import 'gst_filing_history_sheet.dart';

/// Modal bottom sheet for adding or editing an authorized counterparty contact.
/// Supports both GST Certificate OCR extraction (Broker Verified) and Manual entry (GST Verification Pending).
class ContactFormModal extends ConsumerStatefulWidget {
  final bool isEditing;
  final DirectoryContact? existingContact;
  final ContactRole defaultRole;

  const ContactFormModal({
    super.key,
    this.isEditing = false,
    this.existingContact,
    this.defaultRole = ContactRole.buyer,
  });

  static Future<bool?> show(
    BuildContext context, {
    bool isEditing = false,
    DirectoryContact? existingContact,
    ContactRole defaultRole = ContactRole.buyer,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ContactFormModal(
          isEditing: isEditing,
          existingContact: existingContact,
          defaultRole: defaultRole,
        ),
      ),
    );
  }

  @override
  ConsumerState<ContactFormModal> createState() => _ContactFormModalState();
}

class _ContactFormModalState extends ConsumerState<ContactFormModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _mobileController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _notesController;

  late final TextEditingController _gstinController;
  late final TextEditingController _legalNameController;
  late final TextEditingController _tradeNameController;
  late final TextEditingController _constitutionController;
  late final TextEditingController _addressController;

  late final TextEditingController _bankHolderController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _bankIfscController;
  late final TextEditingController _bankBranchController;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;

    _nameController = TextEditingController(text: c?.name ?? '');
    _companyController = TextEditingController(text: c?.companyName ?? '');
    _mobileController = TextEditingController(text: c?.mobile ?? '');
    _whatsappController = TextEditingController(text: c?.whatsapp ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _cityController = TextEditingController(text: c?.city ?? '');
    _stateController = TextEditingController(text: c?.state ?? '');
    _notesController = TextEditingController();

    _gstinController = TextEditingController(text: c?.gstin ?? '');
    _legalNameController = TextEditingController(text: c?.legalName ?? '');
    _tradeNameController = TextEditingController(text: c?.tradeName ?? '');
    _constitutionController = TextEditingController(text: c?.constitution ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');

    _bankHolderController = TextEditingController(text: c?.bankHolderName ?? '');
    _bankNameController = TextEditingController(text: c?.bankName ?? '');
    _bankAccountController = TextEditingController(text: c?.bankAccountNumber ?? '');
    _bankIfscController = TextEditingController(text: c?.bankIfsc ?? '');
    _bankBranchController = TextEditingController(text: c?.bankBranch ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(contactFormControllerProvider.notifier);
      if (widget.isEditing && c != null) {
        ctrl.initForEdit(c);
      } else {
        ctrl.initForCreate(widget.defaultRole);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();

    _gstinController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _constitutionController.dispose();
    _addressController.dispose();

    _bankHolderController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankBranchController.dispose();
    super.dispose();
  }

  void _syncControllersWithState(ContactFormState formState) {
    if (_gstinController.text != formState.gstin) {
      _gstinController.text = formState.gstin;
    }
    if (_legalNameController.text != formState.legalName) {
      _legalNameController.text = formState.legalName;
    }
    if (_tradeNameController.text != formState.tradeName) {
      _tradeNameController.text = formState.tradeName;
    }
    if (_constitutionController.text != formState.constitution) {
      _constitutionController.text = formState.constitution;
    }
    if (_addressController.text != formState.businessAddress) {
      _addressController.text = formState.businessAddress;
    }
    if (_companyController.text != formState.companyName && formState.companyName.isNotEmpty) {
      _companyController.text = formState.companyName;
    }
    if (_stateController.text != formState.state && formState.state.isNotEmpty) {
      _stateController.text = formState.state;
    }
    if (_bankHolderController.text != formState.bankHolderName) {
      _bankHolderController.text = formState.bankHolderName;
    }
    if (_bankNameController.text != formState.bankName) {
      _bankNameController.text = formState.bankName;
    }
    if (_bankAccountController.text != formState.bankAccountNumber) {
      _bankAccountController.text = formState.bankAccountNumber;
    }
    if (_bankIfscController.text != formState.bankIfsc) {
      _bankIfscController.text = formState.bankIfsc;
    }
    if (_bankBranchController.text != formState.bankBranch) {
      _bankBranchController.text = formState.bankBranch;
    }
  }

  Future<void> _pickImage(ImageSource source, {required bool isGst}) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null && mounted) {
        final ctrl = ref.read(contactFormControllerProvider.notifier);
        if (isGst) {
          ctrl.setGstCertificate(file.path);
          await ctrl.extractGstFromImage(path: file.path);
        } else {
          ctrl.setChequeLeaf(file.path);
          await ctrl.extractChequeFromImage(path: file.path);
        }
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(contactFormControllerProvider);
    final formNotifier = ref.read(contactFormControllerProvider.notifier);

    // Sync any OCR updates to text controllers without overriding manual edits
    _syncControllersWithState(formState);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isEditing ? LucideIcons.userCheck : LucideIcons.userPlus,
                    size: 20,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'Edit Counterparty' : 'Add Counterparty',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.isEditing
                            ? 'Update counterparty profile and banking details.'
                            : 'Register a buyer or seller with GST certificate or manual fallback.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Duplicate Warning Banner
                  if (formState.duplicateWarning != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Duplicate Counterparty Detected',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formState.duplicateWarning!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7F1D1D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (formState.duplicateInfo?.isCaseB == true &&
                              formState.duplicateInfo?.existingContactId != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                key: const Key('restore_counterparty_button'),
                                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                                label: const Text('Add Them Back (Restore Relationship)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                onPressed: () async {
                                  final ok = await formNotifier.restoreCounterparty(
                                    formState.duplicateInfo!.existingContactId!,
                                  );
                                  if (ok && context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                              ),
                            ),
                          ],
                          if (formState.duplicateInfo?.isCaseC == true &&
                              formState.duplicateInfo?.existingCompanyId != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                key: const Key('link_shared_counterparty_button'),
                                icon: const Icon(LucideIcons.link2, size: 15),
                                label: const Text('Link to My Directory'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                onPressed: () async {
                                  final ok = await formNotifier.linkSharedCounterparty(
                                    companyId: formState.duplicateInfo!.existingCompanyId!,
                                    userId: formState.duplicateInfo?.existingUserId,
                                  );
                                  if (ok && context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (formState.generalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.info, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formState.generalError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Role Selection
                  const Text(
                    'Counterparty Type *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionTab(
                          label: 'Add Buyer',
                          icon: LucideIcons.shoppingBag,
                          isSelected: formState.role == ContactRole.buyer,
                          selectedColor: const Color(0xFF1E3A8A),
                          onTap: () => formNotifier.updateRole(ContactRole.buyer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOptionTab(
                          label: 'Add Seller',
                          icon: LucideIcons.store,
                          isSelected: formState.role == ContactRole.seller,
                          selectedColor: const Color(0xFFC2410C),
                          onTap: () => formNotifier.updateRole(ContactRole.seller),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Registration Mode (GST Certificate vs Manual)
                  const Text(
                    'Registration Method',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            label: 'GST Certificate (OCR)',
                            icon: LucideIcons.fileCheck2,
                            isSelected: formState.registrationMode == CounterpartyRegistrationMode.gstCertificate,
                            onTap: () => formNotifier.setRegistrationMode(CounterpartyRegistrationMode.gstCertificate),
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            label: 'Enter Manually',
                            icon: LucideIcons.pencilLine,
                            isSelected: formState.registrationMode == CounterpartyRegistrationMode.manual,
                            onTap: () => formNotifier.setRegistrationMode(CounterpartyRegistrationMode.manual),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. GST Certificate Capture & Review (when in certificate mode)
                  if (formState.registrationMode == CounterpartyRegistrationMode.gstCertificate) ...[
                    _buildGstCertificateSection(formState, formNotifier),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Manual mode notice
                    _buildManualGstNotice(formState),
                    const SizedBox(height: 16),
                  ],

                  // 4. Business & GST Details
                  _buildSectionHeader('Business Details', LucideIcons.building2),
                  const SizedBox(height: 10),

                  // GSTIN Field (Mandatory in both paths)
                  _buildTextField(
                    key: const Key('contact_form_gstin_field'),
                    controller: _gstinController,
                    label: 'GSTIN *',
                    hintText: 'e.g. 08ADRPK6597J1ZL',
                    prefixIcon: LucideIcons.hash,
                    errorText: formState.gstinError,
                    helperText: formState.registrationMode == CounterpartyRegistrationMode.gstCertificate
                        ? 'Extracted from Form GST REG-06. Check characters validated.'
                        : 'Mandatory 15-digit GSTIN. Subject to Admin GST verification.',
                    onChanged: formNotifier.updateGstin,
                  ),
                  const SizedBox(height: 14),

                  // Legal Name & Trade Name
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          key: const Key('contact_form_legal_name_field'),
                          controller: _legalNameController,
                          label: 'Legal Name',
                          hintText: 'e.g. Ramesh Khandelwal',
                          prefixIcon: LucideIcons.idCard,
                          onChanged: formNotifier.updateLegalName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          key: const Key('contact_form_trade_name_field'),
                          controller: _tradeNameController,
                          label: 'Trade Name',
                          hintText: 'e.g. Malwa Agro Traders',
                          prefixIcon: LucideIcons.tag,
                          onChanged: formNotifier.updateTradeName,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Business / Company Name
                  _buildTextField(
                    key: const Key('contact_form_company_field'),
                    controller: _companyController,
                    label: 'Business / Company Name *',
                    hintText: 'Trading entity display name',
                    prefixIcon: LucideIcons.building,
                    errorText: formState.companyError,
                    onChanged: formNotifier.updateCompanyName,
                  ),
                  const SizedBox(height: 14),

                  // Business Type / Constitution
                  _buildTextField(
                    key: const Key('contact_form_constitution_field'),
                    controller: _constitutionController,
                    label: 'Business Type',
                    hintText: 'e.g. Proprietorship / Private Limited',
                    prefixIcon: LucideIcons.briefcase,
                    onChanged: formNotifier.updateConstitution,
                  ),
                  const SizedBox(height: 14),

                  // Principal Address
                  _buildTextField(
                    key: const Key('contact_form_address_field'),
                    controller: _addressController,
                    label: 'Business Address',
                    hintText: 'Principal place of business',
                    prefixIcon: LucideIcons.mapPinned,
                    maxLines: 2,
                    onChanged: formNotifier.updateBusinessAddress,
                  ),
                  const SizedBox(height: 14),

                  // Mandi / City & State
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          key: const Key('contact_form_city_field'),
                          controller: _cityController,
                          label: 'Mandi / City',
                          hintText: 'e.g. Jaipur',
                          prefixIcon: LucideIcons.mapPin,
                          onChanged: formNotifier.updateCity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          key: const Key('contact_form_state_field'),
                          controller: _stateController,
                          label: 'State',
                          hintText: 'e.g. Rajasthan',
                          prefixIcon: LucideIcons.map,
                          onChanged: formNotifier.updateState,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // GST Verification Explicit Confirmation Checkbox (for Certificate route)
                  if (formState.registrationMode == CounterpartyRegistrationMode.gstCertificate) ...[
                    _buildGstConfirmationBox(formState, formNotifier),
                    const SizedBox(height: 20),
                  ],

                  // 5. Contact Person Details
                  _buildSectionHeader('Contact Information', LucideIcons.user),
                  const SizedBox(height: 10),

                  _buildTextField(
                    key: const Key('contact_form_name_field'),
                    controller: _nameController,
                    label: 'Contact Person Name *',
                    hintText: 'e.g. Ramesh Agrawal',
                    prefixIcon: LucideIcons.user,
                    errorText: formState.nameError,
                    onChanged: formNotifier.updateName,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    key: const Key('contact_form_mobile_field'),
                    controller: _mobileController,
                    label: 'Mobile Number (+91 Standard) *',
                    hintText: '9876543210',
                    prefixIcon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                    errorText: formState.mobileError,
                    helperText: 'Indian 10-digit mobile number starting with 6, 7, 8, or 9',
                    onChanged: formNotifier.updateMobile,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    key: const Key('contact_form_email_field'),
                    controller: _emailController,
                    label: 'Email Address (Optional)',
                    hintText: 'ramesh@malwaagro.com',
                    prefixIcon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    errorText: formState.emailError,
                    onChanged: formNotifier.updateEmail,
                  ),
                  const SizedBox(height: 14),

                  if (!widget.isEditing) ...[
                    _buildTextField(
                      key: const Key('contact_form_notes_field'),
                      controller: _notesController,
                      label: 'Initial Broker Notes (Optional)',
                      hintText: 'Payment reputation, quality track record...',
                      prefixIcon: LucideIcons.fileText,
                      maxLines: 2,
                      onChanged: formNotifier.updateNotes,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6. Optional Bank Details Section (Cheque Leaf Supported)
                  _buildOptionalBankSection(formState, formNotifier),
                  const SizedBox(height: 20),

                  // Mediation Firewall & Statutory Note
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Broker Mediation Firewall: Counterparties remain strictly mediated by your broker desk. Bank and GST records are protected under secure tenant access control.',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.borderLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          key: const Key('contact_form_submit_button'),
                          onPressed: formState.isSubmitting
                              ? null
                              : () async {
                                  final success = await formNotifier.submit(
                                    isEditing: widget.isEditing,
                                    contactId: widget.existingContact?.id,
                                  );
                                  if (success && context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: formState.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEditing
                                      ? 'Save Changes'
                                      : (formState.role == ContactRole.buyer ? 'Save Buyer' : 'Save Seller'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildGstCertificateSection(
    ContactFormState formState,
    ContactFormController formNotifier,
  ) {
    final hasFile = formState.gstCertificatePath != null;
    final isGstinValid = GstinRules.hasValidFormat(formState.gstin);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileCheck2, size: 18, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GST Certificate (Form REG-06)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OCR Auto-Extract',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Check GST Filing History button beside GST Certificate section
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('check_gst_filing_history_button'),
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
              label: Text(
                isGstinValid
                    ? 'Check GST Filing History'
                    : 'Check GST Filing History (Valid GSTIN Required)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isGstinValid ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
                side: BorderSide(color: isGstinValid ? const Color(0xFF1E3A8A) : Colors.grey.shade300),
                backgroundColor: isGstinValid ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              ),
              onPressed: isGstinValid
                  ? () {
                      GstFilingHistorySheet.show(
                        context,
                        gstin: formState.gstin,
                        companyId: widget.existingContact?.companyId,
                        counterpartyName: formState.companyName,
                      );
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasFile) ...[
            const Text(
              'Photograph or upload the GST certificate. Fields will be automatically read for your review.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('gst_camera_button'),
                    onPressed: () => _pickImage(ImageSource.camera, isGst: true),
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: const Text('Take Photo', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('gst_gallery_button'),
                    onPressed: () => _pickImage(ImageSource.gallery, isGst: true),
                    icon: const Icon(LucideIcons.image, size: 16),
                    label: const Text('Upload from Gallery', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Document preview, rotate, replace controls
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: RotatedBox(
                          quarterTurns: formState.gstCertificateRotation ~/ 90,
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: File(formState.gstCertificatePath!).existsSync()
                                ? Image.file(
                                    File(formState.gstCertificatePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(LucideIcons.fileText, size: 28),
                                  )
                                : const Icon(LucideIcons.fileText, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GST Certificate Loaded',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              formState.isExtractingGst ? 'Extracting details...' : 'Details extracted & prefilled',
                              style: TextStyle(
                                fontSize: 11,
                                color: formState.isExtractingGst ? Colors.amber.shade800 : const Color(0xFF15803D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rotate 90°',
                        icon: const Icon(LucideIcons.rotateCw, size: 18),
                        onPressed: formNotifier.rotateGstCertificate,
                      ),
                      IconButton(
                        tooltip: 'Replace',
                        icon: const Icon(LucideIcons.refreshCw, size: 18),
                        onPressed: () => _pickImage(ImageSource.gallery, isGst: true),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                        onPressed: formNotifier.clearGstCertificate,
                      ),
                    ],
                  ),
                  if (formState.isExtractingGst) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
          ],

          if (formState.gstExtractionError != null) ...[
            const SizedBox(height: 8),
            Text(
              formState.gstExtractionError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualGstNotice(ContactFormState formState) {
    final isGstinValid = GstinRules.hasValidFormat(formState.gstin);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 16, color: Color(0xFF15803D)),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Entry: GST Verification Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Counterparty will be saved as Unverified and an Admin verification request will be created automatically. You will be notified once reviewed.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('manual_check_gst_filing_history_button'),
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
              label: Text(
                isGstinValid
                    ? 'Check GST Filing History'
                    : 'Check GST Filing History (Valid GSTIN Required)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isGstinValid ? const Color(0xFF15803D) : Colors.grey.shade400,
                side: BorderSide(color: isGstinValid ? const Color(0xFF86EFAC) : Colors.grey.shade300),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onPressed: isGstinValid
                  ? () {
                      GstFilingHistorySheet.show(
                        context,
                        gstin: formState.gstin,
                        companyId: widget.existingContact?.companyId,
                        counterpartyName: formState.companyName,
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstConfirmationBox(
    ContactFormState formState,
    ContactFormController formNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: const Key('gst_broker_confirm_checkbox'),
            value: formState.brokerConfirmedGst,
            activeColor: const Color(0xFF1E3A8A),
            onChanged: (val) => formNotifier.setBrokerConfirmedGst(val ?? false),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 6),
                Text(
                  'Broker Verified — Certificate Reviewed',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'I confirm I have reviewed every extracted detail against the uploaded GST certificate. (Note: OCR is not government verification).',
                  style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalBankSection(
    ContactFormState formState,
    ContactFormController formNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.landmark, size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bank Details (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Cheque Leaf Required',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question: Is a cheque leaf available?
          const Text(
            'Is a cheque leaf available for this counterparty?',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('cheque_leaf_no_chip'),
                label: const Text('No (Skip Bank Details)'),
                selected: !formState.hasChequeLeaf,
                onSelected: (selected) {
                  if (selected) formNotifier.setHasChequeLeaf(false);
                },
              ),
              ChoiceChip(
                key: const Key('cheque_leaf_yes_chip'),
                label: const Text('Yes (Cheque Leaf Provided)'),
                selected: formState.hasChequeLeaf,
                onSelected: (selected) {
                  if (selected) formNotifier.setHasChequeLeaf(true);
                },
              ),
            ],
          ),

          if (formState.hasChequeLeaf) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),

            // Cheque Leaf Upload & Preview
            if (formState.chequeLeafPath == null) ...[
              const Text(
                'Upload cheque leaf to extract and record bank details. Details cannot be saved without cheque evidence.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('cheque_camera_button'),
                      onPressed: () => _pickImage(ImageSource.camera, isGst: false),
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('cheque_gallery_button'),
                      onPressed: () => _pickImage(ImageSource.gallery, isGst: false),
                      icon: const Icon(LucideIcons.image, size: 16),
                      label: const Text('Upload from Gallery', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: RotatedBox(
                        quarterTurns: formState.chequeLeafRotation ~/ 90,
                        child: Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade200,
                          child: File(formState.chequeLeafPath!).existsSync()
                              ? Image.file(
                                  File(formState.chequeLeafPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(LucideIcons.landmark, size: 24),
                                )
                              : const Icon(LucideIcons.landmark, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cheque Leaf Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(
                            formState.isExtractingCheque ? 'Extracting bank info...' : 'Details extracted for review',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Rotate',
                      icon: const Icon(LucideIcons.rotateCw, size: 16),
                      onPressed: formNotifier.rotateChequeLeaf,
                    ),
                    IconButton(
                      tooltip: 'Replace',
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      onPressed: () => _pickImage(ImageSource.gallery, isGst: false),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                      onPressed: formNotifier.clearChequeLeaf,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            _buildTextField(
              key: const Key('contact_form_bank_holder_field'),
              controller: _bankHolderController,
              label: 'Account Holder Name',
              hintText: 'e.g. Malwa Agro Traders',
              prefixIcon: LucideIcons.user,
              onChanged: formNotifier.updateBankHolderName,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    key: const Key('contact_form_bank_name_field'),
                    controller: _bankNameController,
                    label: 'Bank Name',
                    hintText: 'e.g. State Bank of India',
                    prefixIcon: LucideIcons.building,
                    onChanged: formNotifier.updateBankName,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    key: const Key('contact_form_bank_branch_field'),
                    controller: _bankBranchController,
                    label: 'Branch',
                    hintText: 'e.g. Bani Park',
                    prefixIcon: LucideIcons.mapPin,
                    onChanged: formNotifier.updateBankBranch,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    key: const Key('contact_form_account_number_field'),
                    controller: _bankAccountController,
                    label: 'Account Number *',
                    hintText: '9 to 18 digits',
                    prefixIcon: LucideIcons.creditCard,
                    keyboardType: TextInputType.number,
                    errorText: formState.bankError,
                    onChanged: formNotifier.updateBankAccountNumber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    key: const Key('contact_form_ifsc_field'),
                    controller: _bankIfscController,
                    label: 'IFSC Code *',
                    hintText: 'e.g. SBIN0001234',
                    prefixIcon: LucideIcons.hash,
                    errorText: formState.ifscError,
                    onChanged: formNotifier.updateBankIfsc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cheque Leaf Confirmation Checkbox
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: const Key('bank_broker_confirm_checkbox'),
                    value: formState.brokerConfirmedBank,
                    onChanged: (val) => formNotifier.setBrokerConfirmedBank(val ?? false),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6),
                        Text(
                          'Cheque Leaf Provided — Broker Recorded',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'I confirm that the bank details entered match the attached cheque leaf copy. (Recorded as broker-reviewed, not bank-verified).',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryNavy),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.borderLight,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? selectedColor : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? errorText,
    String? helperText,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textSecondary),
            errorText: errorText,
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
