import 'cheque_extracted_data.dart';
import 'seller_profile_model.dart';

/// Contextual contact phone candidate extracted from an invoice.
class PhoneCandidate {
  final String number; // Normalized 10-digit number e.g. "9829012345"
  final String rawMatch; // Raw match as printed e.g. "+91 98290-12345"
  final String contextLabel; // e.g. "Seller Contact", "Buyer Contact", "General Contact"
  final bool isSellerCandidate;

  const PhoneCandidate({
    required this.number,
    required this.rawMatch,
    this.contextLabel = 'Seller Contact',
    this.isSellerCandidate = true,
  });

  Map<String, dynamic> toMap() => {
        'number': number,
        'raw_match': rawMatch,
        'context_label': contextLabel,
        'is_seller_candidate': isSellerCandidate,
      };

  factory PhoneCandidate.fromMap(Map<String, dynamic> map) => PhoneCandidate(
        number: map['number']?.toString() ?? '',
        rawMatch: map['raw_match']?.toString() ?? '',
        contextLabel: map['context_label']?.toString() ?? 'Contact',
        isSellerCandidate: map['is_seller_candidate'] != false,
      );

  @override
  String toString() => '$contextLabel: $rawMatch ($number)';
}

/// Represents a structured line item from an invoice table.
class InvoiceLineItem {
  final String description; // e.g. "Mustard Bold", "सरसों", "Soybean Yellow"
  final String? hsnCode; // e.g. "1204", "1201"
  final double? quantity; // e.g. 100.0, 200.0
  final String? unit; // e.g. "Qtl", "Bags", "बोरी", "क्विंटल"
  final double? rate; // e.g. 5400.0
  final double? amount; // e.g. 1080000.0
  final bool isHandwritten;
  final bool isUncertain;
  final String? uncertaintyReason;

  const InvoiceLineItem({
    required this.description,
    this.hsnCode,
    this.quantity,
    this.unit,
    this.rate,
    this.amount,
    this.isHandwritten = false,
    this.isUncertain = false,
    this.uncertaintyReason,
  });

  Map<String, dynamic> toMap() => {
        'description': description,
        'hsn_code': hsnCode,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'amount': amount,
        'is_handwritten': isHandwritten,
        'is_uncertain': isUncertain,
        'uncertainty_reason': uncertaintyReason,
      };

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) => InvoiceLineItem(
        description: map['description']?.toString() ?? '',
        hsnCode: map['hsn_code']?.toString(),
        quantity: map['quantity'] != null ? double.tryParse(map['quantity'].toString()) : null,
        unit: map['unit']?.toString(),
        rate: map['rate'] != null ? double.tryParse(map['rate'].toString()) : null,
        amount: map['amount'] != null ? double.tryParse(map['amount'].toString()) : null,
        isHandwritten: map['is_handwritten'] == true,
        isUncertain: map['is_uncertain'] == true,
        uncertaintyReason: map['uncertainty_reason']?.toString(),
      );
}

/// Represents Buyer (Consignee / Billed To / ग्राहक) details extracted from an invoice.
class BuyerDetails {
  final String? buyerName;
  final String? gstin;
  final String? address;
  final String? contactMobile;
  final String? state;
  final String? district;
  final String? pinCode;
  final bool isHandwritten;

  const BuyerDetails({
    this.buyerName,
    this.gstin,
    this.address,
    this.contactMobile,
    this.state,
    this.district,
    this.pinCode,
    this.isHandwritten = false,
  });

  Map<String, dynamic> toMap() => {
        'buyer_name': buyerName,
        'gstin': gstin,
        'address': address,
        'contact_mobile': contactMobile,
        'state': state,
        'district': district,
        'pin_code': pinCode,
        'is_handwritten': isHandwritten,
      };

  factory BuyerDetails.fromMap(Map<String, dynamic> map) => BuyerDetails(
        buyerName: map['buyer_name']?.toString(),
        gstin: map['gstin']?.toString(),
        address: map['address']?.toString(),
        contactMobile: map['contact_mobile']?.toString(),
        state: map['state']?.toString(),
        district: map['district']?.toString(),
        pinCode: map['pin_code']?.toString(),
        isHandwritten: map['is_handwritten'] == true,
      );
}

/// Financial summary, charges, and totals.
class InvoiceFinancials {
  final double? subtotal;
  final double? freightCharges;
  final String? freightAnnotation; // e.g. "Freight Paid: Rs 12,000", "To Pay"
  final double? taxAmount;
  final double? discountAmount;
  final double? grandTotal;
  final String? amountInWords;
  final String? paymentStatus; // e.g. "Advance Received", "Paid", "Pending"

  const InvoiceFinancials({
    this.subtotal,
    this.freightCharges,
    this.freightAnnotation,
    this.taxAmount,
    this.discountAmount,
    this.grandTotal,
    this.amountInWords,
    this.paymentStatus,
  });

  Map<String, dynamic> toMap() => {
        'subtotal': subtotal,
        'freight_charges': freightCharges,
        'freight_annotation': freightAnnotation,
        'tax_amount': taxAmount,
        'discount_amount': discountAmount,
        'grand_total': grandTotal,
        'amount_in_words': amountInWords,
        'payment_status': paymentStatus,
      };

  factory InvoiceFinancials.fromMap(Map<String, dynamic> map) => InvoiceFinancials(
        subtotal: map['subtotal'] != null ? double.tryParse(map['subtotal'].toString()) : null,
        freightCharges: map['freight_charges'] != null ? double.tryParse(map['freight_charges'].toString()) : null,
        freightAnnotation: map['freight_annotation']?.toString(),
        taxAmount: map['tax_amount'] != null ? double.tryParse(map['tax_amount'].toString()) : null,
        discountAmount: map['discount_amount'] != null ? double.tryParse(map['discount_amount'].toString()) : null,
        grandTotal: map['grand_total'] != null ? double.tryParse(map['grand_total'].toString()) : null,
        amountInWords: map['amount_in_words']?.toString(),
        paymentStatus: map['payment_status']?.toString(),
      );
}

/// Value object representing structured business data extracted from a business invoice.
/// STRICT PRINCIPLES:
/// - Unverified suggestions only; must never automatically overwrite authoritative data without explicit seller confirmation.
/// - Never fabricate or hallucinate missing data. Missing values remain empty/null.
/// - Bank details are strictly unverified even when extracted.
/// - Preserves original language and script (Devanagari for Hindi, Latin for English).
/// - Arithmetic discrepancies between quantity * rate and amount raise review warnings without silent modification.
class InvoiceExtractedData {
  final String? firmName;
  final String? gstin;
  final String? email; // Supplier email, only when printed on the invoice
  final String? officeAddress;
  final String? state;
  final String? district;
  final String? pinCode;
  final String? contactMobile;
  final List<PhoneCandidate> phoneCandidates;
  final bool hasPinAddressConflict;
  final String? pinConflictNotice;
  final bool isHindiDocument;
  final Map<String, String> addressCandidates;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? vehicleNumber;
  final String? transportType;
  final String? documentType;
  final BuyerDetails? buyerDetails;
  final List<InvoiceLineItem> lineItems;
  final InvoiceFinancials? financials;
  final bool hasArithmeticMismatch;
  final String? arithmeticMismatchNotice;
  final List<String> uncertainFields;
  final bool hasHandwrittenContent;
  final String? accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? branchName;
  final String? micrCode;
  final String? chequeNumber;
  final List<String> extractedCommodities;
  final double confidenceScore;
  final String? rawTextPreview;

  const InvoiceExtractedData({
    this.firmName,
    this.gstin,
    this.email,
    this.officeAddress,
    this.state,
    this.district,
    this.pinCode,
    this.contactMobile,
    this.phoneCandidates = const [],
    this.hasPinAddressConflict = false,
    this.pinConflictNotice,
    this.isHindiDocument = false,
    this.addressCandidates = const {},
    this.invoiceNumber,
    this.invoiceDate,
    this.vehicleNumber,
    this.transportType,
    this.documentType,
    this.buyerDetails,
    this.lineItems = const [],
    this.financials,
    this.hasArithmeticMismatch = false,
    this.arithmeticMismatchNotice,
    this.uncertainFields = const [],
    this.hasHandwrittenContent = false,
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.branchName,
    this.micrCode,
    this.chequeNumber,
    this.extractedCommodities = const [],
    this.confidenceScore = 0.0,
    this.rawTextPreview,
  });

  // Convenience getters
  String? get buyerName => buyerDetails?.buyerName;
  String? get buyerGstin => buyerDetails?.gstin;
  String? get buyerAddress => buyerDetails?.address;
  String? get buyerMobile => buyerDetails?.contactMobile;
  double? get grandTotal => financials?.grandTotal;
  double? get freightCharges => financials?.freightCharges;
  String? get freightAnnotation => financials?.freightAnnotation;
  String? get paymentStatus => financials?.paymentStatus;
  double? get subtotal => financials?.subtotal;

  /// Merges bank details from a cheque photo into this invoice data.
  InvoiceExtractedData mergeWithCheque(ChequeExtractedData cheque) {
    return InvoiceExtractedData(
      firmName: firmName,
      gstin: gstin,
      email: email,
      officeAddress: officeAddress,
      state: state,
      district: district,
      pinCode: pinCode,
      contactMobile: contactMobile,
      phoneCandidates: phoneCandidates,
      hasPinAddressConflict: hasPinAddressConflict,
      pinConflictNotice: pinConflictNotice,
      isHindiDocument: isHindiDocument,
      addressCandidates: addressCandidates,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      vehicleNumber: vehicleNumber,
      transportType: transportType,
      documentType: documentType,
      buyerDetails: buyerDetails,
      lineItems: lineItems,
      financials: financials,
      hasArithmeticMismatch: hasArithmeticMismatch,
      arithmeticMismatchNotice: arithmeticMismatchNotice,
      uncertainFields: uncertainFields,
      hasHandwrittenContent: hasHandwrittenContent,
      accountHolderName: cheque.accountHolderName ?? accountHolderName,
      bankName: cheque.bankName ?? bankName,
      accountNumber: cheque.accountNumber ?? accountNumber,
      ifscCode: cheque.ifscCode ?? ifscCode,
      branchName: cheque.branchName ?? branchName,
      micrCode: cheque.micrCode ?? micrCode,
      chequeNumber: cheque.chequeNumber ?? chequeNumber,
      extractedCommodities: extractedCommodities,
      confidenceScore: confidenceScore,
      rawTextPreview: rawTextPreview,
    );
  }

  bool get isEmpty =>
      (firmName == null || firmName!.isEmpty) &&
      (gstin == null || gstin!.isEmpty) &&
      (officeAddress == null || officeAddress!.isEmpty) &&
      (contactMobile == null || contactMobile!.isEmpty) &&
      (accountNumber == null || accountNumber!.isEmpty) &&
      (ifscCode == null || ifscCode!.isEmpty) &&
      extractedCommodities.isEmpty &&
      lineItems.isEmpty;

  bool get hasBankDetails =>
      (accountNumber != null && accountNumber!.isNotEmpty) ||
      (ifscCode != null && ifscCode!.isNotEmpty);

  /// Computes a list of field names that differ from current profile.
  List<String> getChangedFieldNames(SellerProfileModel profile) {
    final changed = <String>[];
    if (firmName != null && firmName!.isNotEmpty && firmName != profile.fullName) {
      changed.add('Full Name');
    }
    if (firmName != null && firmName!.isNotEmpty && firmName != profile.companyName) {
      changed.add('Business Name');
    }
    if (gstin != null && gstin!.isNotEmpty && gstin != profile.companyGst) {
      changed.add('GSTIN');
    }
    if (officeAddress != null && officeAddress!.isNotEmpty && officeAddress != profile.officeAddress) {
      changed.add('Office Address');
    }
    if (contactMobile != null && contactMobile!.isNotEmpty && contactMobile != profile.mobile) {
      changed.add('Mobile Number');
    }
    if (state != null && state!.isNotEmpty && state != profile.businessLocation.stateName) {
      changed.add('State');
    }
    if (district != null && district!.isNotEmpty && district != profile.businessLocation.districtName) {
      changed.add('District');
    }
    if (pinCode != null && pinCode!.isNotEmpty && pinCode != profile.businessLocation.pinCode) {
      changed.add('PIN Code');
    }
    if (accountNumber != null && accountNumber!.isNotEmpty && accountNumber != profile.bankDetails.accountNumber) {
      changed.add('Bank Account Number');
    }
    if (ifscCode != null && ifscCode!.isNotEmpty && ifscCode != profile.bankDetails.ifscCode) {
      changed.add('IFSC Code');
    }
    if (bankName != null && bankName!.isNotEmpty && bankName != profile.bankDetails.bankName) {
      changed.add('Bank Name');
    }
    if (accountHolderName != null && accountHolderName!.isNotEmpty && accountHolderName != profile.bankDetails.accountHolderName) {
      changed.add('Account Holder Name');
    }
    return changed;
  }

  /// Authoritatively maps supplier invoice data to the SellerProfileModel according to
  /// mandatory field-mapping specifications:
  /// - Supplier / Business Name -> Supplier's business or firm name
  /// - Business Identifier -> Firm Name (Strictly Firm Name, NEVER GSTIN!)
  /// - Version Identifier -> Form Name (documentType / form name when present)
  /// - GST Number / GSTIN -> Supplier's GSTIN (Never buyer's GSTIN)
  /// - Contact Details Mobile -> Supplier's mobile number (Never buyer's mobile)
  /// - Shop and Godown Address -> Supplier's address
  /// - Location and Street -> Complete supplier address
  /// - Corporate Office / HQ Address -> Complete supplier address
  /// - State -> Supplier's state, validated against PIN code where possible
  /// - District -> Supplier's district, validated against PIN code where possible
  /// - PIN Code -> PIN code from supplier's address
  /// - Bank Name -> Supplier's bank name
  /// - Account Number -> Supplier's bank account number
  /// - IFSC Code -> Supplier's IFSC code
  /// - Bank Branch / Location -> Supplier's bank branch
  SellerProfileModel mapToSellerProfile(SellerProfileModel current) {
    final sFirm = (firmName != null && firmName!.trim().isNotEmpty) ? firmName!.trim() : null;
    final sGstin = (gstin != null && gstin!.trim().isNotEmpty) ? gstin!.trim() : null;
    final sDocType = (documentType != null && documentType!.trim().isNotEmpty) ? documentType!.trim() : null;
    final sMobile = (contactMobile != null && contactMobile!.trim().isNotEmpty) ? contactMobile!.trim() : null;
    final sAddr = (officeAddress != null && officeAddress!.trim().isNotEmpty) ? officeAddress!.trim() : null;
    final sPin = (pinCode != null && pinCode!.trim().isNotEmpty) ? pinCode!.trim() : null;
    final sState = (state != null && state!.trim().isNotEmpty) ? state!.trim() : null;
    final sDistrict = (district != null && district!.trim().isNotEmpty) ? district!.trim() : null;

    final sBankName = (bankName != null && bankName!.trim().isNotEmpty) ? bankName!.trim() : null;
    final sAccount = (accountNumber != null && accountNumber!.trim().isNotEmpty) ? accountNumber!.trim() : null;
    final sIfsc = (ifscCode != null && ifscCode!.trim().isNotEmpty) ? ifscCode!.trim().toUpperCase() : null;
    final sBranch = (branchName != null && branchName!.trim().isNotEmpty) ? branchName!.trim() : null;
    final sHolder = (accountHolderName != null && accountHolderName!.trim().isNotEmpty) ? accountHolderName!.trim() : null;

    // Supplier address reused across Shop/Godown, Location/Street, and Corporate Office
    final effectiveAddr = sAddr ?? current.officeAddress;
    final effectivePin = sPin ?? current.businessLocation.pinCode;
    final effectiveState = sState ?? current.state;
    final effectiveDistrict = sDistrict ?? current.district;

    final updatedLocation = current.businessLocation.copyWith(
      name: sFirm ?? current.businessLocation.name, // Location Name = supplier firm name
      addressLine: sAddr ?? current.businessLocation.addressLine, // Street / Mandi / Area Address
      pinCode: effectivePin,
      stateName: effectiveState,
      districtName: effectiveDistrict,
    );

    final updatedBank = current.bankDetails.copyWith(
      accountHolderName: sHolder ?? current.bankDetails.accountHolderName,
      bankName: sBankName ?? current.bankDetails.bankName,
      accountNumber: sAccount ?? current.bankDetails.accountNumber,
      ifscCode: sIfsc ?? current.bankDetails.ifscCode,
      branchName: sBranch ?? current.bankDetails.branchName,
    );

    // Email is intentionally not mapped: profile email is the login identity (read-only in the
    // profile form), so invoice email is surfaced for review only and never overwrites it.
    return current.copyWith(
      fullName: sFirm ?? current.fullName,
      companyName: sFirm ?? current.companyName,
      // INVARIANT: Business Identifier = Firm Name (Never GSTIN)
      businessIdentifier: sFirm ?? (current.businessIdentifier.isNotEmpty ? current.businessIdentifier : current.companyName),
      // INVARIANT: Version Identifier = Form Name
      versionIdentifier: sDocType ?? current.versionIdentifier,
      // INVARIANT: Supplier GSTIN only
      companyGst: sGstin ?? current.companyGst,
      // INVARIANT: Supplier Mobile only
      mobile: sMobile ?? current.mobile,
      officeAddress: effectiveAddr,
      state: effectiveState,
      district: effectiveDistrict,
      businessLocation: updatedLocation,
      bankDetails: updatedBank,
    );
  }

  InvoiceExtractedData copyWith({
    String? firmName,
    String? gstin,
    String? email,
    String? officeAddress,
    String? state,
    String? district,
    String? pinCode,
    String? contactMobile,
    List<PhoneCandidate>? phoneCandidates,
    bool? hasPinAddressConflict,
    String? pinConflictNotice,
    bool? isHindiDocument,
    Map<String, String>? addressCandidates,
    String? invoiceNumber,
    String? invoiceDate,
    String? vehicleNumber,
    String? transportType,
    String? documentType,
    BuyerDetails? buyerDetails,
    List<InvoiceLineItem>? lineItems,
    InvoiceFinancials? financials,
    bool? hasArithmeticMismatch,
    String? arithmeticMismatchNotice,
    List<String>? uncertainFields,
    bool? hasHandwrittenContent,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? branchName,
    String? micrCode,
    String? chequeNumber,
    List<String>? extractedCommodities,
    double? confidenceScore,
    String? rawTextPreview,
  }) {
    return InvoiceExtractedData(
      firmName: firmName ?? this.firmName,
      gstin: gstin ?? this.gstin,
      email: email ?? this.email,
      officeAddress: officeAddress ?? this.officeAddress,
      state: state ?? this.state,
      district: district ?? this.district,
      pinCode: pinCode ?? this.pinCode,
      contactMobile: contactMobile ?? this.contactMobile,
      phoneCandidates: phoneCandidates ?? this.phoneCandidates,
      hasPinAddressConflict: hasPinAddressConflict ?? this.hasPinAddressConflict,
      pinConflictNotice: pinConflictNotice ?? this.pinConflictNotice,
      isHindiDocument: isHindiDocument ?? this.isHindiDocument,
      addressCandidates: addressCandidates ?? this.addressCandidates,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      transportType: transportType ?? this.transportType,
      documentType: documentType ?? this.documentType,
      buyerDetails: buyerDetails ?? this.buyerDetails,
      lineItems: lineItems ?? this.lineItems,
      financials: financials ?? this.financials,
      hasArithmeticMismatch: hasArithmeticMismatch ?? this.hasArithmeticMismatch,
      arithmeticMismatchNotice: arithmeticMismatchNotice ?? this.arithmeticMismatchNotice,
      uncertainFields: uncertainFields ?? this.uncertainFields,
      hasHandwrittenContent: hasHandwrittenContent ?? this.hasHandwrittenContent,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branchName: branchName ?? this.branchName,
      micrCode: micrCode ?? this.micrCode,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      extractedCommodities: extractedCommodities ?? this.extractedCommodities,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawTextPreview: rawTextPreview ?? this.rawTextPreview,
    );
  }

  factory InvoiceExtractedData.fromMap(Map<String, dynamic> map) {
    List<String> commodities = [];
    if (map['extracted_commodities'] is List) {
      commodities = (map['extracted_commodities'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (map['commodities'] is List) {
      commodities = (map['commodities'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<PhoneCandidate> candidates = [];
    if (map['phone_candidates'] is List) {
      candidates = (map['phone_candidates'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => PhoneCandidate.fromMap(m))
          .toList();
    }

    Map<String, String> addrs = {};
    if (map['address_candidates'] is Map) {
      (map['address_candidates'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          addrs[k.toString()] = v.toString();
        }
      });
    }

    List<InvoiceLineItem> items = [];
    if (map['line_items'] is List) {
      items = (map['line_items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => InvoiceLineItem.fromMap(m))
          .toList();
    }

    BuyerDetails? buyer;
    if (map['buyer_details'] is Map<String, dynamic>) {
      buyer = BuyerDetails.fromMap(map['buyer_details'] as Map<String, dynamic>);
    }

    InvoiceFinancials? fin;
    if (map['financials'] is Map<String, dynamic>) {
      fin = InvoiceFinancials.fromMap(map['financials'] as Map<String, dynamic>);
    }

    List<String> uncertains = [];
    if (map['uncertain_fields'] is List) {
      uncertains = (map['uncertain_fields'] as List).map((e) => e.toString()).toList();
    }

    return InvoiceExtractedData(
      firmName: map['firm_name']?.toString() ?? map['firmName']?.toString(),
      gstin: map['gstin']?.toString() ?? map['gst']?.toString(),
      email: map['email']?.toString(),
      officeAddress: map['office_address']?.toString() ?? map['officeAddress']?.toString(),
      state: map['state']?.toString(),
      district: map['district']?.toString(),
      pinCode: map['pin_code']?.toString() ?? map['pinCode']?.toString(),
      contactMobile: map['contact_mobile']?.toString() ?? map['contactMobile']?.toString(),
      phoneCandidates: candidates,
      hasPinAddressConflict: map['has_pin_address_conflict'] == true,
      pinConflictNotice: map['pin_conflict_notice']?.toString(),
      isHindiDocument: map['is_hindi_document'] == true,
      addressCandidates: addrs,
      invoiceNumber: map['invoice_number']?.toString() ?? map['invoiceNumber']?.toString(),
      invoiceDate: map['invoice_date']?.toString() ?? map['invoiceDate']?.toString(),
      vehicleNumber: map['vehicle_number']?.toString(),
      transportType: map['transport_type']?.toString(),
      documentType: map['document_type']?.toString(),
      buyerDetails: buyer,
      lineItems: items,
      financials: fin,
      hasArithmeticMismatch: map['has_arithmetic_mismatch'] == true,
      arithmeticMismatchNotice: map['arithmetic_mismatch_notice']?.toString(),
      uncertainFields: uncertains,
      hasHandwrittenContent: map['has_handwritten_content'] == true,
      accountHolderName: map['account_holder_name']?.toString() ?? map['accountHolderName']?.toString(),
      bankName: map['bank_name']?.toString() ?? map['bankName']?.toString(),
      accountNumber: map['account_number']?.toString() ?? map['accountNumber']?.toString(),
      ifscCode: map['ifsc_code']?.toString() ?? map['ifscCode']?.toString(),
      branchName: map['branch_name']?.toString() ?? map['branchName']?.toString(),
      micrCode: map['micr_code']?.toString() ?? map['micrCode']?.toString(),
      chequeNumber: map['cheque_number']?.toString() ?? map['chequeNumber']?.toString(),
      extractedCommodities: commodities,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.0,
      rawTextPreview: map['raw_text_preview']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firm_name': firmName,
      'gstin': gstin,
      'email': email,
      'office_address': officeAddress,
      'state': state,
      'district': district,
      'pin_code': pinCode,
      'contact_mobile': contactMobile,
      'phone_candidates': phoneCandidates.map((c) => c.toMap()).toList(),
      'has_pin_address_conflict': hasPinAddressConflict,
      'pin_conflict_notice': pinConflictNotice,
      'is_hindi_document': isHindiDocument,
      'address_candidates': addressCandidates,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'vehicle_number': vehicleNumber,
      'transport_type': transportType,
      'document_type': documentType,
      'buyer_details': buyerDetails?.toMap(),
      'line_items': lineItems.map((item) => item.toMap()).toList(),
      'financials': financials?.toMap(),
      'has_arithmetic_mismatch': hasArithmeticMismatch,
      'arithmetic_mismatch_notice': arithmeticMismatchNotice,
      'uncertain_fields': uncertainFields,
      'has_handwritten_content': hasHandwrittenContent,
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'branch_name': branchName,
      'micr_code': micrCode,
      'cheque_number': chequeNumber,
      'extracted_commodities': extractedCommodities,
      'confidence_score': confidenceScore,
      'raw_text_preview': rawTextPreview,
    };
  }
}
