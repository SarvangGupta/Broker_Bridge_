import 'seller_profile_model.dart';

/// Values read from a Form GST REG-06 Registration Certificate.
///
/// These are unverified OCR suggestions: they never prove that the GSTIN or the
/// registration is valid, and they are only saved after the seller confirms.
class GstCertificateExtractedData {
  final String? legalName;
  final String? tradeName;
  final String? gstin;

  /// True when OCR confusables (e.g. letter O for digit 0) were repaired using the
  /// GSTIN check character; the seller should still compare it with the certificate.
  final bool gstinCorrected;
  final String? constitution;
  final String? principalAddress;
  final String? pinCode;
  final String? state;
  final String? district;
  final String? jurisdictionalOffice;
  final String? issueDate;

  /// True when the issue date was identified from the layout rather than its label.
  final bool issueDateInferred;
  final String? dateOfLiability;
  final List<String> reviewNotes;

  const GstCertificateExtractedData({
    this.legalName,
    this.tradeName,
    this.gstin,
    this.gstinCorrected = false,
    this.constitution,
    this.principalAddress,
    this.pinCode,
    this.state,
    this.district,
    this.jurisdictionalOffice,
    this.issueDate,
    this.issueDateInferred = false,
    this.dateOfLiability,
    this.reviewNotes = const [],
  });

  bool get isEmpty =>
      legalName == null && tradeName == null && gstin == null && principalAddress == null;

  /// Business Name suggestion: Trade Name, else the Legal Name (seller reviews it).
  String? get suggestedBusinessName => tradeName ?? legalName;

  /// Applies the certificate to a profile. Missing values keep the current ones.
  /// The shop/godown address and PIN are only filled when the seller confirms that the
  /// principal place of business is also the shop/godown ([addressIsGodown]).
  SellerProfileModel applyToProfile(SellerProfileModel current, {bool addressIsGodown = false}) {
    final loc = current.businessLocation;
    return current.copyWith(
      fullName: legalName ?? current.fullName,
      companyName: suggestedBusinessName ?? current.companyName,
      businessIdentifier: suggestedBusinessName ?? current.businessIdentifier,
      companyGst: gstin ?? current.companyGst,
      officeAddress: principalAddress ?? current.officeAddress,
      state: state ?? current.state,
      district: district ?? current.district,
      jurisdictionalOffice: jurisdictionalOffice ?? current.jurisdictionalOffice,
      gstCertificateIssueDate: issueDate ?? current.gstCertificateIssueDate,
      businessLocation: addressIsGodown && principalAddress != null
          ? loc.copyWith(
              addressLine: principalAddress,
              pinCode: pinCode ?? loc.pinCode,
              stateName: state ?? loc.stateName,
              districtName: district ?? loc.districtName,
            )
          : loc,
    );
  }
}
