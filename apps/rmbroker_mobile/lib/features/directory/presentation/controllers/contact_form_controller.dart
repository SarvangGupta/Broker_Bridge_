import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/directory_repository.dart';
import '../../domain/directory_contact.dart';
import '../../utils/phone_utils.dart';
import 'directory_controller.dart';

/// Form state for adding or editing a counterparty contact.
class ContactFormState {
  final String name;
  final String companyName;
  final String mobile;
  final String whatsapp;
  final String email;
  final ContactRole role;
  final String city;
  final String state;
  final String notes;
  final bool? status;

  final bool isSubmitting;
  final String? nameError;
  final String? companyError;
  final String? mobileError;
  final String? emailError;
  final String? generalError;
  final String? duplicateWarning;
  final bool isSuccess;
  final String? createdContactId;

  const ContactFormState({
    this.name = '',
    this.companyName = '',
    this.mobile = '',
    this.whatsapp = '',
    this.email = '',
    this.role = ContactRole.buyer,
    this.city = '',
    this.state = '',
    this.notes = '',
    this.status = true,
    this.isSubmitting = false,
    this.nameError,
    this.companyError,
    this.mobileError,
    this.emailError,
    this.generalError,
    this.duplicateWarning,
    this.isSuccess = false,
    this.createdContactId,
  });

  bool get isValid =>
      nameError == null &&
      companyError == null &&
      mobileError == null &&
      emailError == null &&
      name.trim().length >= 2 &&
      companyName.trim().length >= 2 &&
      mobile.trim().isNotEmpty;

  ContactFormState copyWith({
    String? name,
    String? companyName,
    String? mobile,
    String? whatsapp,
    String? email,
    ContactRole? role,
    String? city,
    String? state,
    String? notes,
    bool? status,
    bool? isSubmitting,
    String? nameError,
    String? companyError,
    String? mobileError,
    String? emailError,
    String? generalError,
    String? duplicateWarning,
    bool? isSuccess,
    String? createdContactId,
    bool clearErrors = false,
  }) {
    return ContactFormState(
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      mobile: mobile ?? this.mobile,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      role: role ?? this.role,
      city: city ?? this.city,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      nameError: clearErrors ? null : (nameError ?? this.nameError),
      companyError: clearErrors ? null : (companyError ?? this.companyError),
      mobileError: clearErrors ? null : (mobileError ?? this.mobileError),
      emailError: clearErrors ? null : (emailError ?? this.emailError),
      generalError: clearErrors ? null : (generalError ?? this.generalError),
      duplicateWarning: clearErrors ? null : (duplicateWarning ?? this.duplicateWarning),
      isSuccess: isSuccess ?? this.isSuccess,
      createdContactId: createdContactId ?? this.createdContactId,
    );
  }
}

/// Controller managing add/edit contact form validation, duplicate checking, and submission.
class ContactFormController extends Notifier<ContactFormState> {
  DirectoryRepository get _repository => ref.read(directoryRepositoryProvider);

  @override
  ContactFormState build() {
    return const ContactFormState();
  }

  void initForCreate([ContactRole defaultRole = ContactRole.buyer]) {
    state = ContactFormState(role: defaultRole);
  }

  void initForEdit(DirectoryContact contact) {
    state = ContactFormState(
      name: contact.name,
      companyName: contact.companyName,
      mobile: contact.mobile,
      whatsapp: contact.whatsapp ?? '',
      email: contact.email ?? '',
      role: contact.role,
      city: contact.city ?? '',
      state: contact.state ?? '',
      status: contact.status,
    );
  }

  void updateName(String val) {
    state = state.copyWith(
      name: val,
      nameError: val.trim().length < 2 ? 'Name must be at least 2 characters' : null,
      clearErrors: false,
    );
  }

  void updateCompanyName(String val) {
    state = state.copyWith(
      companyName: val,
      companyError: val.trim().length < 2 ? 'Company name must be at least 2 characters' : null,
      clearErrors: false,
    );
  }

  void updateMobile(String val) {
    final validation = PhoneUtils.validateAndNormalize(val);
    state = state.copyWith(
      mobile: val,
      mobileError: validation.isValid ? null : validation.error,
      duplicateWarning: null,
      clearErrors: false,
    );
  }

  void updateWhatsapp(String val) {
    state = state.copyWith(whatsapp: val);
  }

  void updateEmail(String val) {
    final trimmed = val.trim();
    String? err;
    if (trimmed.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(trimmed)) {
      err = 'Invalid email address';
    }
    state = state.copyWith(email: val, emailError: err);
  }

  void updateRole(ContactRole role) {
    state = state.copyWith(role: role);
  }

  void updateCity(String val) {
    state = state.copyWith(city: val);
  }

  void updateState(String val) {
    state = state.copyWith(state: val);
  }

  void updateNotes(String val) {
    state = state.copyWith(notes: val);
  }

  /// Validates all fields prior to submit.
  bool validate() {
    String? nameErr;
    String? compErr;
    String? mobileErr;
    String? emailErr;

    if (state.name.trim().length < 2) {
      nameErr = 'Contact person name must be at least 2 characters';
    }
    if (state.companyName.trim().length < 2) {
      compErr = 'Company name must be at least 2 characters';
    }

    final pVal = PhoneUtils.validateAndNormalize(state.mobile);
    if (!pVal.isValid) {
      mobileErr = pVal.error ?? 'Invalid mobile number';
    }

    if (state.email.trim().isNotEmpty &&
        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(state.email.trim())) {
      emailErr = 'Invalid email address';
    }

    state = state.copyWith(
      nameError: nameErr,
      companyError: compErr,
      mobileError: mobileErr,
      emailError: emailErr,
      generalError: null,
    );

    return nameErr == null && compErr == null && mobileErr == null && emailErr == null;
  }

  /// Submit contact payload to server (add or edit).
  Future<bool> submit({bool isEditing = false, String? contactId}) async {
    if (!validate()) return false;
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, generalError: null, duplicateWarning: null);

    final phoneRes = PhoneUtils.validateAndNormalize(state.mobile);

    if (isEditing && contactId != null) {
      // 1. Update existing contact
      final input = UpdateContactInput(
        name: state.name,
        companyName: state.companyName,
        mobile: phoneRes.normalized,
        whatsapp: state.whatsapp,
        email: state.email,
        role: state.role,
        city: state.city,
        state: state.state,
        notes: state.notes,
        status: state.status,
      );

      final result = await _repository.updateContact(contactId, input);

      switch (result) {
        case DirectorySuccess<bool>():
          state = state.copyWith(isSubmitting: false, isSuccess: true);
          // Reload directory
          ref.read(directoryControllerProvider.notifier).loadContacts(isRefresh: true);
          return true;

        case DirectoryError<bool>(:final message, :final isDuplicate):
          state = state.copyWith(
            isSubmitting: false,
            duplicateWarning: isDuplicate ? message : null,
            generalError: isDuplicate ? null : message,
          );
          return false;

        case DirectoryUnavailable<bool>(:final contractNotice):
          state = state.copyWith(isSubmitting: false, generalError: contractNotice);
          return false;

        case DirectoryUnauthorized<bool>(:final message):
          state = state.copyWith(isSubmitting: false, generalError: message);
          return false;
      }
    } else {
      // 2. Create new contact
      final input = CreateContactInput(
        name: state.name,
        companyName: state.companyName,
        mobile: phoneRes.normalized,
        whatsapp: state.whatsapp,
        email: state.email,
        role: state.role,
        city: state.city,
        state: state.state,
        notes: state.notes,
      );

      final result = await _repository.createContact(input);

      switch (result) {
        case DirectorySuccess<String>(:final data):
          state = state.copyWith(
            isSubmitting: false,
            isSuccess: true,
            createdContactId: data,
          );
          // Reload directory
          ref.read(directoryControllerProvider.notifier).loadContacts(isRefresh: true);
          return true;

        case DirectoryError<String>(:final message, :final isDuplicate):
          state = state.copyWith(
            isSubmitting: false,
            duplicateWarning: isDuplicate ? message : null,
            generalError: isDuplicate ? null : message,
          );
          return false;

        case DirectoryUnavailable<String>(:final contractNotice):
          state = state.copyWith(isSubmitting: false, generalError: contractNotice);
          return false;

        case DirectoryUnauthorized<String>(:final message):
          state = state.copyWith(isSubmitting: false, generalError: message);
          return false;
      }
    }
  }
}

/// Provider for ContactFormController.
final contactFormControllerProvider =
    NotifierProvider<ContactFormController, ContactFormState>(() {
  return ContactFormController();
});
