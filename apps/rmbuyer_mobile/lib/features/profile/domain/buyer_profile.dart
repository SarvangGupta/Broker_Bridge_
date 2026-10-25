/// The signed-in buyer's profile as stored in `public.users` and `public.companies`.
///
/// Only [name] and [mobile] are editable by the buyer. Email is the sign-in
/// identity, and the company record (name, GSTIN, verification) is governed by
/// verification, so they are read-only in the app.
class BuyerProfile {
  final String id;
  final String name;
  final String? mobile;
  final String? email;
  final String role;
  final String? companyId;
  final String? companyName;
  final String? companyGst;
  final bool? companyVerified;

  const BuyerProfile({
    required this.id,
    required this.name,
    required this.role,
    this.mobile,
    this.email,
    this.companyId,
    this.companyName,
    this.companyGst,
    this.companyVerified,
  });

  BuyerProfile copyWith({
    String? name,
    String? mobile,
    bool clearMobile = false,
  }) {
    return BuyerProfile(
      id: id,
      name: name ?? this.name,
      mobile: clearMobile ? null : (mobile ?? this.mobile),
      email: email,
      role: role,
      companyId: companyId,
      companyName: companyName,
      companyGst: companyGst,
      companyVerified: companyVerified,
    );
  }
}

/// Field rules for the editable profile fields.
class BuyerProfileValidation {
  const BuyerProfileValidation._();

  static const int nameMin = 2;
  static const int nameMax = 80;

  /// Null when valid; otherwise which rule failed.
  static NameError? validateName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return NameError.required;
    if (name.length < nameMin || name.length > nameMax) return NameError.length;
    return null;
  }

  /// Indian mobile number: optional +91 / 91 / 0 prefix, then 10 digits
  /// starting 6–9. Spaces and hyphens are ignored. Returns `+91XXXXXXXXXX`,
  /// or null when [raw] is not a valid number.
  static String? normalizeMobile(String raw) {
    var digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? '+91$digits' : null;
  }
}

enum NameError { required, length }
