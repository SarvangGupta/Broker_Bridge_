import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/directory_repository.dart';
import '../../data/ocr_extraction_service.dart';
import '../../domain/cheque_leaf_data.dart';
import '../../domain/directory_contact.dart';
import '../../domain/gst_certificate_data.dart';
import '../../utils/phone_utils.dart';
import 'directory_controller.dart';

enum CounterpartyRegistrationMode {
  gstCertificate('GST Certificate (OCR)'),
  manual('Enter Manually');

  final String label;
  const CounterpartyRegistrationMode(this.label);
}

/// Form state for adding or editing a counterparty contact.
@immutable
class ContactFormState {
  // Mode & Role
  final CounterpartyRegistrationMode registrationMode;
  final ContactRole role;

  // Basic Contact Details
  final String name;
  final String companyName;
  final String mobile;
  final String whatsapp;
  final String email;
  final String city;
  final String state;
  final String notes;
  final bool? status;

  // GST Certificate & Business Details
  final String? gstCertificatePath;
  final int gstCertificateRotation; // in degrees: 0, 90, 180, 270
  final bool isExtractingGst;
  final String? gstExtractionError;
  final GstCertificateData? gstData;
  final String gstin;
  final String legalName;
  final String tradeName;
  final String constitution;
  final String businessAddress;
  final String registrationDate;
  final String gstStatus;
  final bool brokerConfirmedGst;

  // Optional Bank Details (Requires Cheque Leaf)
  final bool hasChequeLeaf;
  final String? chequeLeafPath;
  final int chequeLeafRotation; // in degrees: 0, 90, 180, 270
  final bool isExtractingCheque;
  final String? chequeExtractionError;
  final ChequeLeafData? chequeData;
  final String bankHolderName;
  final String bankName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankBranch;
  final bool brokerConfirmedBank;

  // Form Validation & Progress State
  final bool isSubmitting;
  final String? nameError;
  final String? companyError;
  final String? mobileError;
  final String? emailError;
  final String? gstinError;
  final String? bankError;
  final String? ifscError;
  final String? generalError;
  final String? duplicateWarning;
  final DuplicateCheckResult? duplicateInfo;
  final bool isSuccess;
  final String? createdContactId;

  const ContactFormState({
    this.registrationMode = CounterpartyRegistrationMode.gstCertificate,
    this.role = ContactRole.buyer,
    this.name = '',
    this.companyName = '',
    this.mobile = '',
    this.whatsapp = '',
    this.email = '',
    this.city = '',
    this.state = '',
    this.notes = '',
    this.status = true,
    this.gstCertificatePath,
    this.gstCertificateRotation = 0,
    this.isExtractingGst = false,
    this.gstExtractionError,
    this.gstData,
    this.gstin = '',
    this.legalName = '',
    this.tradeName = '',
    this.constitution = '',
    this.businessAddress = '',
    this.registrationDate = '',
    this.gstStatus = 'Active',
    this.brokerConfirmedGst = false,
    this.hasChequeLeaf = false,
    this.chequeLeafPath,
    this.chequeLeafRotation = 0,
    this.isExtractingCheque = false,
    this.chequeExtractionError,
    this.chequeData,
    this.bankHolderName = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankBranch = '',
    this.brokerConfirmedBank = false,
    this.isSubmitting = false,
    this.nameError,
    this.companyError,
    this.mobileError,
    this.emailError,
    this.gstinError,
    this.bankError,
    this.ifscError,
    this.generalError,
    this.duplicateWarning,
    this.duplicateInfo,
    this.isSuccess = false,
    this.createdContactId,
  });

  bool get isValid =>
      nameError == null &&
      companyError == null &&
      mobileError == null &&
      emailError == null &&
      gstinError == null &&
      bankError == null &&
      ifscError == null &&
      name.trim().length >= 2 &&
      companyName.trim().length >= 2 &&
      mobile.trim().isNotEmpty &&
      gstin.trim().isNotEmpty;

  static const Object _keep = Object();

  ContactFormState copyWith({
    CounterpartyRegistrationMode? registrationMode,
    ContactRole? role,
    String? name,
    String? companyName,
    String? mobile,
    String? whatsapp,
    String? email,
    String? city,
    String? state,
    String? notes,
    bool? status,
    Object? gstCertificatePath = _keep,
    int? gstCertificateRotation,
    bool? isExtractingGst,
    Object? gstExtractionError = _keep,
    Object? gstData = _keep,
    String? gstin,
    String? legalName,
    String? tradeName,
    String? constitution,
    String? businessAddress,
    String? registrationDate,
    String? gstStatus,
    bool? brokerConfirmedGst,
    bool? hasChequeLeaf,
    Object? chequeLeafPath = _keep,
    int? chequeLeafRotation,
    bool? isExtractingCheque,
    Object? chequeExtractionError = _keep,
    Object? chequeData = _keep,
    String? bankHolderName,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    bool? brokerConfirmedBank,
    bool? isSubmitting,
    Object? nameError = _keep,
    Object? companyError = _keep,
    Object? mobileError = _keep,
    Object? emailError = _keep,
    Object? gstinError = _keep,
    Object? bankError = _keep,
    Object? ifscError = _keep,
    Object? generalError = _keep,
    Object? duplicateWarning = _keep,
    Object? duplicateInfo = _keep,
    bool? isSuccess,
    String? createdContactId,
    bool clearErrors = false,
  }) {
    T? pick<T>(Object? next, T? current) =>
        clearErrors ? null : (identical(next, _keep) ? current : next as T?);

    return ContactFormState(
      registrationMode: registrationMode ?? this.registrationMode,
      role: role ?? this.role,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      mobile: mobile ?? this.mobile,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      city: city ?? this.city,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      gstCertificatePath: pick(gstCertificatePath, this.gstCertificatePath),
      gstCertificateRotation: gstCertificateRotation ?? this.gstCertificateRotation,
      isExtractingGst: isExtractingGst ?? this.isExtractingGst,
      gstExtractionError: pick(gstExtractionError, this.gstExtractionError),
      gstData: pick(gstData, this.gstData),
      gstin: gstin ?? this.gstin,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      constitution: constitution ?? this.constitution,
      businessAddress: businessAddress ?? this.businessAddress,
      registrationDate: registrationDate ?? this.registrationDate,
      gstStatus: gstStatus ?? this.gstStatus,
      brokerConfirmedGst: brokerConfirmedGst ?? this.brokerConfirmedGst,
      hasChequeLeaf: hasChequeLeaf ?? this.hasChequeLeaf,
      chequeLeafPath: pick(chequeLeafPath, this.chequeLeafPath),
      chequeLeafRotation: chequeLeafRotation ?? this.chequeLeafRotation,
      isExtractingCheque: isExtractingCheque ?? this.isExtractingCheque,
      chequeExtractionError: pick(chequeExtractionError, this.chequeExtractionError),
      chequeData: pick(chequeData, this.chequeData),
      bankHolderName: bankHolderName ?? this.bankHolderName,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankBranch: bankBranch ?? this.bankBranch,
      brokerConfirmedBank: brokerConfirmedBank ?? this.brokerConfirmedBank,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      nameError: pick(nameError, this.nameError),
      companyError: pick(companyError, this.companyError),
      mobileError: pick(mobileError, this.mobileError),
      emailError: pick(emailError, this.emailError),
      gstinError: pick(gstinError, this.gstinError),
      bankError: pick(bankError, this.bankError),
      ifscError: pick(ifscError, this.ifscError),
      generalError: pick(generalError, this.generalError),
      duplicateWarning: pick(duplicateWarning, this.duplicateWarning),
      duplicateInfo: pick(duplicateInfo, this.duplicateInfo),
      isSuccess: isSuccess ?? this.isSuccess,
      createdContactId: createdContactId ?? this.createdContactId,
    );
  }
}

/// Controller managing add/edit contact form validation, OCR extraction, duplicate checking, and submission.
class ContactFormController extends Notifier<ContactFormState> {
  DirectoryRepository get _repository => ref.read(directoryRepositoryProvider);
  OcrExtractionService _ocrService = const OcrExtractionService();

  @visibleForTesting
  void setOcrService(OcrExtractionService service) {
    _ocrService = service;
  }

  @override
  ContactFormState build() {
    return const ContactFormState();
  }

  String? _storedCity;
  String? _storedState;
  String _shownCity = '';
  String _shownState = '';

  void initForCreate([ContactRole defaultRole = ContactRole.buyer]) {
    _storedCity = _storedState = null;
    _shownCity = _shownState = '';
    state = ContactFormState(role: defaultRole);
  }

  void initForEdit(DirectoryContact contact) {
    _storedCity = contact.city;
    _storedState = contact.state;
    _shownCity = contact.cityLabel ?? '';
    _shownState = contact.stateLabel ?? '';
    state = ContactFormState(
      registrationMode: CounterpartyRegistrationMode.manual,
      role: contact.role,
      name: contact.name,
      companyName: contact.companyName,
      mobile: contact.mobile,
      whatsapp: contact.whatsapp ?? '',
      email: contact.email ?? '',
      city: _shownCity,
      state: _shownState,
      status: contact.status,
      gstin: contact.gstin ?? '',
      legalName: contact.legalName ?? '',
      tradeName: contact.tradeName ?? '',
      constitution: contact.constitution ?? '',
      businessAddress: contact.address ?? '',
      bankHolderName: contact.bankHolderName ?? '',
      bankName: contact.bankName ?? '',
      bankAccountNumber: contact.bankAccountNumber ?? '',
      bankIfsc: contact.bankIfsc ?? '',
      bankBranch: contact.bankBranch ?? '',
      hasChequeLeaf: contact.hasChequeLeaf,
    );
  }

  @visibleForTesting
  static String locationToSave(String typed, String shown, String? stored) =>
      typed.trim() == shown.trim() && stored != null ? stored : typed;

  void setRegistrationMode(CounterpartyRegistrationMode mode) {
    state = state.copyWith(registrationMode: mode, clearErrors: true);
  }

  void updateRole(ContactRole role) {
    state = state.copyWith(role: role);
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

  void updateWhatsapp(String val) => state = state.copyWith(whatsapp: val);

  void updateEmail(String val) {
    final trimmed = val.trim();
    String? err;
    if (trimmed.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(trimmed)) {
      err = 'Invalid email address';
    }
    state = state.copyWith(email: val, emailError: err);
  }

  void updateCity(String val) => state = state.copyWith(city: val);
  void updateState(String val) => state = state.copyWith(state: val);
  void updateNotes(String val) => state = state.copyWith(notes: val);

  // --- GST Actions ---

  void setGstCertificate(String path) {
    state = state.copyWith(
      gstCertificatePath: path,
      gstCertificateRotation: 0,
      gstExtractionError: null,
    );
  }

  void rotateGstCertificate() {
    final nextRotation = (state.gstCertificateRotation + 90) % 360;
    state = state.copyWith(gstCertificateRotation: nextRotation);
  }

  void replaceGstCertificate(String newPath) {
    setGstCertificate(newPath);
    extractGstFromImage(path: newPath);
  }

  void clearGstCertificate() {
    state = state.copyWith(
      gstCertificatePath: null,
      gstCertificateRotation: 0,
      gstData: null,
      brokerConfirmedGst: false,
      gstExtractionError: null,
    );
  }

  Future<void> extractGstFromImage({String? path, ImageTextRecognizer? recognizer}) async {
    final imagePath = path ?? state.gstCertificatePath;
    if (imagePath == null) return;

    state = state.copyWith(isExtractingGst: true, gstExtractionError: null);
    final ocrService = recognizer != null ? OcrExtractionService(recognizer: recognizer) : _ocrService;
    final result = await ocrService.extractGstCertificate(imagePath);

    if (result.isSuccess && result.data != null) {
      final d = result.data!;
      final g = d.gstin ?? '';
      final autoCompName = (d.tradeName != null && d.tradeName!.isNotEmpty)
          ? d.tradeName!
          : (d.legalName ?? state.companyName);

      state = state.copyWith(
        isExtractingGst: false,
        gstData: d,
        gstin: g,
        legalName: d.legalName ?? state.legalName,
        tradeName: d.tradeName ?? state.tradeName,
        constitution: d.constitution ?? state.constitution,
        businessAddress: d.principalAddress ?? state.businessAddress,
        state: d.state ?? state.state,
        companyName: autoCompName.isNotEmpty ? autoCompName : state.companyName,
        registrationDate: d.registrationDate ?? state.registrationDate,
        gstStatus: d.gstStatus ?? 'Active',
        gstinError: null,
      );
    } else {
      state = state.copyWith(
        isExtractingGst: false,
        gstExtractionError: result.errorMessage ?? 'Failed to extract certificate details.',
      );
    }
  }

  void updateGstin(String val) {
    final clean = GstinRules.normalize(val);
    String? err;
    if (clean.isNotEmpty) {
      if (!GstinRules.hasValidFormat(clean)) {
        err = 'Invalid GSTIN format (15 alphanumeric characters)';
      } else if (!GstinRules.isValid(clean)) {
        err = 'Invalid GSTIN check digit. Please compare with certificate.';
      }
    }
    final derivedState = GstinRules.stateOf(clean) ?? state.state;
    state = state.copyWith(
      gstin: clean,
      state: derivedState,
      gstinError: err,
      duplicateWarning: null,
    );
  }

  void updateLegalName(String val) => state = state.copyWith(legalName: val);
  void updateTradeName(String val) => state = state.copyWith(tradeName: val);
  void updateConstitution(String val) => state = state.copyWith(constitution: val);
  void updateBusinessAddress(String val) => state = state.copyWith(businessAddress: val);
  void setBrokerConfirmedGst(bool val) => state = state.copyWith(brokerConfirmedGst: val);

  // --- Bank Details Actions ---

  void setHasChequeLeaf(bool val) {
    state = state.copyWith(hasChequeLeaf: val);
  }

  void setChequeLeaf(String path) {
    state = state.copyWith(
      chequeLeafPath: path,
      chequeLeafRotation: 0,
      chequeExtractionError: null,
    );
  }

  void rotateChequeLeaf() {
    final nextRotation = (state.chequeLeafRotation + 90) % 360;
    state = state.copyWith(chequeLeafRotation: nextRotation);
  }

  void replaceChequeLeaf(String newPath) {
    setChequeLeaf(newPath);
    extractChequeFromImage(path: newPath);
  }

  void clearChequeLeaf() {
    state = state.copyWith(
      chequeLeafPath: null,
      chequeLeafRotation: 0,
      chequeData: null,
      brokerConfirmedBank: false,
      chequeExtractionError: null,
    );
  }

  Future<void> extractChequeFromImage({String? path, ImageTextRecognizer? recognizer}) async {
    final imagePath = path ?? state.chequeLeafPath;
    if (imagePath == null) return;

    state = state.copyWith(isExtractingCheque: true, chequeExtractionError: null);
    final ocrService = recognizer != null ? OcrExtractionService(recognizer: recognizer) : _ocrService;
    final result = await ocrService.extractChequeLeaf(imagePath);

    if (result.isSuccess && result.data != null) {
      final d = result.data!;
      state = state.copyWith(
        isExtractingCheque: false,
        chequeData: d,
        bankHolderName: d.accountHolderName ?? state.bankHolderName,
        bankName: d.bankName ?? state.bankName,
        bankAccountNumber: d.accountNumber ?? state.bankAccountNumber,
        bankIfsc: d.ifsc ?? state.bankIfsc,
        bankBranch: d.branch ?? state.bankBranch,
        bankError: null,
        ifscError: null,
      );
    } else {
      state = state.copyWith(
        isExtractingCheque: false,
        chequeExtractionError: result.errorMessage ?? 'Failed to extract cheque leaf details.',
      );
    }
  }

  void updateBankHolderName(String val) => state = state.copyWith(bankHolderName: val);
  void updateBankName(String val) => state = state.copyWith(bankName: val);

  void updateBankAccountNumber(String val) {
    final clean = val.replaceAll(RegExp(r'\s'), '');
    String? err;
    if (clean.isNotEmpty && clean.length < 9) {
      err = 'Account number must be at least 9 digits';
    }
    state = state.copyWith(bankAccountNumber: clean, bankError: err);
  }

  void updateBankIfsc(String val) {
    final clean = val.trim().toUpperCase();
    String? err;
    if (clean.isNotEmpty && !IfscRules.hasValidFormat(clean)) {
      err = 'Invalid IFSC code (e.g. SBIN0001234)';
    }
    final autoBankName = IfscRules.bankNameFromIfsc(clean) ?? state.bankName;
    state = state.copyWith(bankIfsc: clean, bankName: autoBankName, ifscError: err);
  }

  void updateBankBranch(String val) => state = state.copyWith(bankBranch: val);
  void setBrokerConfirmedBank(bool val) => state = state.copyWith(brokerConfirmedBank: val);

  /// Validates all fields prior to submit.
  bool validate() {
    String? nameErr;
    String? compErr;
    String? mobileErr;
    String? emailErr;
    String? gstErr;
    String? bErr;
    String? iErr;

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

    // GSTIN is mandatory for BOTH registration modes
    final cleanGstin = GstinRules.normalize(state.gstin);
    if (cleanGstin.isEmpty) {
      gstErr = 'GSTIN is mandatory for counterparty registration';
    } else if (!GstinRules.hasValidFormat(cleanGstin)) {
      gstErr = 'Invalid GSTIN format (15 characters)';
    } else if (!GstinRules.isValid(cleanGstin)) {
      gstErr = 'Invalid GSTIN check character';
    }

    // Mode-specific validation
    if (state.registrationMode == CounterpartyRegistrationMode.gstCertificate) {
      if (state.gstCertificatePath == null) {
        gstErr = gstErr ?? 'Please capture or upload a GST certificate image';
      } else if (!state.brokerConfirmedGst) {
        gstErr = gstErr ?? 'Please confirm that you have reviewed the certificate details';
      }
    }

    // Bank details validation (if provided)
    if (state.hasChequeLeaf) {
      if (state.chequeLeafPath == null) {
        bErr = 'Cheque leaf photo is required to record bank details';
      } else if (state.bankAccountNumber.trim().isEmpty) {
        bErr = 'Bank account number is required';
      } else if (state.bankAccountNumber.trim().length < 9) {
        bErr = 'Bank account number must be at least 9 digits';
      }

      if (state.bankIfsc.trim().isEmpty) {
        iErr = 'Bank IFSC code is required';
      } else if (!IfscRules.hasValidFormat(state.bankIfsc)) {
        iErr = 'Invalid IFSC code (e.g. SBIN0001234)';
      }

      if (bErr == null && iErr == null && !state.brokerConfirmedBank) {
        bErr = 'Please confirm that bank details match the uploaded cheque leaf';
      }
    }

    state = state.copyWith(
      nameError: nameErr,
      companyError: compErr,
      mobileError: mobileErr,
      emailError: emailErr,
      gstinError: gstErr,
      bankError: bErr,
      ifscError: iErr,
      generalError: null,
    );

    return nameErr == null &&
        compErr == null &&
        mobileErr == null &&
        emailErr == null &&
        gstErr == null &&
        bErr == null &&
        iErr == null;
  }

  /// Submit contact payload to server (add or edit).
  Future<bool> submit({bool isEditing = false, String? contactId}) async {
    if (!validate()) return false;
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, generalError: null, duplicateWarning: null);

    final phoneRes = PhoneUtils.validateAndNormalize(state.mobile);
    final cleanGstin = GstinRules.normalize(state.gstin);

    if (isEditing && contactId != null) {
      final isCertMode = state.registrationMode == CounterpartyRegistrationMode.gstCertificate;
      final gstVerificationStatus = isCertMode
          ? CounterpartyGstStatus.brokerVerified
          : (cleanGstin.isNotEmpty ? (state.gstData?.gstStatus != null ? CounterpartyGstStatus.portalMatched : CounterpartyGstStatus.gstPending) : CounterpartyGstStatus.missing);

      final input = UpdateContactInput(
        name: state.name,
        companyName: state.companyName,
        mobile: phoneRes.normalized,
        whatsapp: state.whatsapp,
        email: state.email,
        role: state.role,
        city: locationToSave(state.city, _shownCity, _storedCity),
        state: locationToSave(state.state, _shownState, _storedState),
        notes: state.notes,
        status: state.status,
        gstin: cleanGstin.isNotEmpty ? cleanGstin : null,
        legalName: state.legalName.isNotEmpty ? state.legalName : null,
        tradeName: state.tradeName.isNotEmpty ? state.tradeName : null,
        constitution: state.constitution.isNotEmpty ? state.constitution : null,
        address: state.businessAddress.isNotEmpty ? state.businessAddress : null,
        gstVerificationStatus: gstVerificationStatus,
        gstCertificateUrl: isCertMode ? state.gstCertificatePath : null,
        bankHolderName: state.hasChequeLeaf && state.bankHolderName.isNotEmpty ? state.bankHolderName : null,
        bankName: state.hasChequeLeaf && state.bankName.isNotEmpty ? state.bankName : null,
        bankAccountNumber: state.hasChequeLeaf && state.bankAccountNumber.isNotEmpty ? state.bankAccountNumber : null,
        bankIfsc: state.hasChequeLeaf && state.bankIfsc.isNotEmpty ? state.bankIfsc : null,
        bankBranch: state.hasChequeLeaf && state.bankBranch.isNotEmpty ? state.bankBranch : null,
        bankChequeUrl: state.hasChequeLeaf ? state.chequeLeafPath : null,
        bankVerificationStatus: state.hasChequeLeaf ? CounterpartyBankStatus.chequeLeafProvided : null,
      );

      final result = await _repository.updateContact(contactId, input);
      switch (result) {
        case DirectorySuccess<bool>():
          state = state.copyWith(isSubmitting: false, isSuccess: true);
          ref.read(directoryControllerProvider.notifier).loadContacts(isRefresh: true);
          return true;
        case DirectoryError<bool>(:final message, :final isDuplicate, :final duplicateInfo):
          state = state.copyWith(
            isSubmitting: false,
            duplicateWarning: isDuplicate ? message : null,
            duplicateInfo: duplicateInfo,
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
      // Create new counterparty
      final isCertMode = state.registrationMode == CounterpartyRegistrationMode.gstCertificate;
      final gstVerificationStatus = isCertMode
          ? CounterpartyGstStatus.brokerVerified
          : CounterpartyGstStatus.gstPending;

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
        gstin: cleanGstin,
        legalName: state.legalName.isNotEmpty ? state.legalName : null,
        tradeName: state.tradeName.isNotEmpty ? state.tradeName : null,
        constitution: state.constitution.isNotEmpty ? state.constitution : null,
        address: state.businessAddress.isNotEmpty ? state.businessAddress : null,
        gstRegistrationDate: state.registrationDate.isNotEmpty ? state.registrationDate : null,
        gstVerificationStatus: gstVerificationStatus,
        gstCertificateUrl: isCertMode ? state.gstCertificatePath : null,
        isBrokerVerified: isCertMode,
        bankHolderName: state.hasChequeLeaf && state.bankHolderName.isNotEmpty ? state.bankHolderName : null,
        bankName: state.hasChequeLeaf && state.bankName.isNotEmpty ? state.bankName : null,
        bankAccountNumber: state.hasChequeLeaf && state.bankAccountNumber.isNotEmpty ? state.bankAccountNumber : null,
        bankIfsc: state.hasChequeLeaf && state.bankIfsc.isNotEmpty ? state.bankIfsc : null,
        bankBranch: state.hasChequeLeaf && state.bankBranch.isNotEmpty ? state.bankBranch : null,
        bankChequeUrl: state.hasChequeLeaf ? state.chequeLeafPath : null,
        bankVerificationStatus: state.hasChequeLeaf
            ? CounterpartyBankStatus.chequeLeafProvided
            : CounterpartyBankStatus.unverified,
        hasChequeLeaf: state.hasChequeLeaf,
      );

      final result = await _repository.createContact(input);
      switch (result) {
        case DirectorySuccess<String>(:final data):
          state = state.copyWith(
            isSubmitting: false,
            isSuccess: true,
            createdContactId: data,
          );
          ref.read(directoryControllerProvider.notifier).loadContacts(isRefresh: true);
          return true;
        case DirectoryError<String>(:final message, :final isDuplicate, :final duplicateInfo):
          state = state.copyWith(
            isSubmitting: false,
            duplicateWarning: isDuplicate ? message : null,
            duplicateInfo: duplicateInfo,
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

  /// Restore existing previously removed contact (Case B).
  Future<bool> restoreCounterparty(String contactId) async {
    final success = await ref.read(directoryControllerProvider.notifier).restoreContact(contactId);
    if (success) {
      state = state.copyWith(isSuccess: true);
    }
    return success;
  }

  /// Link existing counterparty from shared database (Case C).
  Future<bool> linkSharedCounterparty({required String companyId, String? userId}) async {
    final success = await ref.read(directoryControllerProvider.notifier).linkSharedCounterparty(
      companyId: companyId,
      userId: userId,
      notes: state.notes.isNotEmpty ? state.notes : null,
    );
    if (success) {
      state = state.copyWith(isSuccess: true);
    }
    return success;
  }
}

/// Provider for ContactFormController.
final contactFormControllerProvider =
    NotifierProvider<ContactFormController, ContactFormState>(() {
  return ContactFormController();
});
