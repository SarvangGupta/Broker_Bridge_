import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';
import '../controllers/contact_form_controller.dart';

/// Modal bottom sheet for adding or editing an authorized counterparty contact.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(contactFormControllerProvider);
    final formNotifier = ref.read(contactFormControllerProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                            ? 'Update contact details and business assignments.'
                            : 'Register a verified buyer or seller under your broker desk.',
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
                  // Server / Duplicate Warning Banner
                  if (formState.duplicateWarning != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Duplicate Contact Detected',
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

                  // Role Selector
                  const Text(
                    'Counterparty Role *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleRadioOption(
                          label: 'Buyer',
                          icon: LucideIcons.shoppingBag,
                          role: ContactRole.buyer,
                          isSelected: formState.role == ContactRole.buyer,
                          onTap: () => formNotifier.updateRole(ContactRole.buyer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRoleRadioOption(
                          label: 'Seller',
                          icon: LucideIcons.store,
                          role: ContactRole.seller,
                          isSelected: formState.role == ContactRole.seller,
                          onTap: () => formNotifier.updateRole(ContactRole.seller),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Person Name
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

                  // Company Name
                  _buildTextField(
                    key: const Key('contact_form_company_field'),
                    controller: _companyController,
                    label: 'Business / Company Name *',
                    hintText: 'e.g. Malwa Agro Traders',
                    prefixIcon: LucideIcons.building2,
                    errorText: formState.companyError,
                    onChanged: formNotifier.updateCompanyName,
                  ),
                  const SizedBox(height: 14),

                  // Mobile Number
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

                  // Location (City & State)
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
                  const SizedBox(height: 14),

                  // Email (Optional)
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

                  // Notes (Optional, create mode)
                  if (!widget.isEditing) ...[
                    _buildTextField(
                      key: const Key('contact_form_notes_field'),
                      controller: _notesController,
                      label: 'Initial Broker Notes (Optional)',
                      hintText: 'Commodity preferences, payment terms, or mandi reputation...',
                      prefixIcon: LucideIcons.fileText,
                      maxLines: 2,
                      onChanged: formNotifier.updateNotes,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statutory Broker Warning
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
                        Icon(LucideIcons.shield, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data Isolation: Counterparties registered here remain strictly linked to your broker desk. Client details are protected under ADR-004 broker mediation.',
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
                                  widget.isEditing ? 'Save Changes' : 'Register Counterparty',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRadioOption({
    required String label,
    required IconData icon,
    required ContactRole role,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = role == ContactRole.buyer ? const Color(0xFF1E3A8A) : const Color(0xFF0D9488);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
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
            helperStyle: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
