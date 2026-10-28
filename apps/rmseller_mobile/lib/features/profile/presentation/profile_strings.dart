import 'package:flutter/material.dart';
import '../../../core/preferences/app_settings_provider.dart';

/// Comprehensive bilingual (English & Hindi) localization dictionary for Seller Profile & Invoice OCR.
/// Conforms to MICRO-SPRINT RB-SELLER-I18N-OCR-01 specifications.
class ProfileStrings {
  final bool isHindi;

  const ProfileStrings({this.isHindi = false});

  factory ProfileStrings.fromLang(AppLanguagePreference lang) {
    return ProfileStrings(isHindi: lang == AppLanguagePreference.hi);
  }

  factory ProfileStrings.fromLocale(Locale locale) {
    return ProfileStrings(isHindi: locale.languageCode == 'hi');
  }

  factory ProfileStrings.of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale?.languageCode == 'hi') {
      return const ProfileStrings(isHindi: true);
    }
    return const ProfileStrings(isHindi: false);
  }

  // Mandatory Table Translations
  String get editProfile => isHindi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile';
  String get cancel => isHindi ? 'रद्द करें' : 'Cancel';
  String get save => isHindi ? 'सेव करें' : 'Save';
  String get scanBusinessInvoice => isHindi ? 'व्यवसाय का बिल स्कैन करें' : 'Scan Business Invoice';
  String get camera => isHindi ? 'कैमरा' : 'Camera';
  String get gallery => isHindi ? 'गैलरी' : 'Gallery';
  String get pdfOrFile => isHindi ? 'PDF / फ़ाइल' : 'PDF / File';
  String get businessDetails => isHindi ? 'व्यवसाय का विवरण' : 'Business Details';
  String get businessName => isHindi ? 'व्यवसाय का नाम' : 'Business Name';
  String get corporateOfficeHqAddress => isHindi ? 'कॉर्पोरेट कार्यालय का मुख्य पता' : 'Corporate Office HQ Address';
  String get confirmAndSave => isHindi ? 'पुष्टि करें और सेव करें' : 'Confirm and Save';
  String get reviewExtractedDetails => isHindi ? 'निकाली गई जानकारी की समीक्षा करें' : 'Review Extracted Details';
  String get retryScan => isHindi ? 'दोबारा स्कैन करें' : 'Retry Scan';
  String get ocrInProgress => isHindi ? 'दस्तावेज़ पढ़ा जा रहा है' : 'OCR in progress';
  String get textExtractionFailed => isHindi ? 'दस्तावेज़ से जानकारी नहीं निकाली जा सकी' : 'Text extraction failed';

  // Invoice Scanner & Actions
  String get scanInvoiceSubtitle => isHindi
      ? 'सत्यापित व्यवसाय और बैंक विवरण भरने के लिए बिल का स्रोत चुनें।'
      : 'Select invoice source to prefill verified business and bank details.';
  String get takePhotoCameraTitle => isHindi ? 'कैमरे से फ़ोटो लें' : 'Take Photo with Camera';
  String get takePhotoCameraSub => isHindi ? 'भौतिक बिल या इनवॉइस की स्पष्ट फ़ोटो खींचें' : 'Capture clear photo of physical invoice or bill';
  String get chooseGalleryTitle => isHindi ? 'फ़ोटो गैलरी से चुनें' : 'Choose from Photo Gallery';
  String get chooseGallerySub => isHindi ? 'गैलरी से स्कैन की गई छवि चुनें' : 'Pick scanned image from photo gallery';
  String get selectPdfTitle => isHindi ? 'PDF दस्तावेज़ चुनें' : 'Select PDF Document';
  String get selectPdfSub => isHindi ? 'इलेक्ट्रॉनिक टैक्स इनवॉइस PDF चुनें' : 'Select electronic tax invoice PDF';
  String get applySuggestions => isHindi ? 'सुझाव लागू करें' : 'Apply Suggestions';
  String get viewDocument => isHindi ? 'दस्तावेज़ देखें' : 'View Document';
  String get removeDocument => isHindi ? 'दस्तावेज़ हटाएं' : 'Remove Document';
  String get invoiceSourceNotice => isHindi
      ? 'बिल से निकाली गई जानकारी ड्राफ्ट में भरी गई है। सेव करने से पहले पुष्टि करना अनिवार्य है।'
      : 'Extracted suggestions applied to draft. Mandatory confirmation required before saving.';
  String get suggestionsAppliedSnack => isHindi
      ? 'बिल के सुझाव फॉर्म में लागू कर दिए गए हैं। कृपया सेव करने से पहले समीक्षा करें।'
      : 'Invoice suggestions applied to form. Please review before saving.';
  String get ocrSuccessNotice => isHindi
      ? 'दस्तावेज़ सफलतापूर्वक पढ़ा गया। विवरण की समीक्षा करें और फॉर्म में भरने के लिए "सुझाव लागू करें" पर टैप करें।'
      : 'Invoice data extracted. Review and tap "Apply Suggestions" to prefill.';
  String get genuineOcrEngineBadge => isHindi ? 'डिवाइस पर असली OCR इंजन सक्रिय' : 'On-Device Genuine OCR Active';
  String get ocrBlockedNotice => isHindi
      ? 'इस बिल्ड में ऑन-डिवाइस OCR इंजन उपलब्ध नहीं है। आप दस्तावेज़ देख सकते हैं और विवरण मैन्युअल रूप से दर्ज कर सकते हैं।'
      : 'On-device native OCR engine is not bundled in this build. You can inspect your genuine document preview, and review or enter details manually.';

  // General Profile Strings
  String get sellerProfileTitle => isHindi ? 'प्रोफ़ाइल' : 'Profile';
  String get myProfile => isHindi ? 'मेरी प्रोफ़ाइल' : 'My Profile';
  String get switchLanguage => isHindi ? 'English' : 'हिन्दी';
  String get verifiedSellerBadge => isHindi ? 'सत्यापित विक्रेता' : 'Verified Seller';
  String get auditHistoryTitle => isHindi ? 'प्रोफ़ाइल परिवर्तन इतिहास (ऑडिट)' : 'Profile Change History (Audit)';
  String get auditHistorySubtitle => isHindi
      ? 'प्रशासक द्वारा सत्यापन और अनुपालन के लिए सभी स्वीकृत परिवर्तनों का रिकॉर्ड।'
      : 'Authoritative record of all confirmed profile updates for administrative audit and compliance.';
  String get noAuditHistory => isHindi ? 'अभी तक कोई प्रोफ़ाइल परिवर्तन दर्ज नहीं हुआ है।' : 'No profile modifications recorded yet.';

  // Section Headers & Subtitles
  String get personalContactDetails => isHindi ? 'व्यक्तिगत और संपर्क विवरण' : 'Personal & Contact Details';
  String get contactDetailsSub => isHindi ? 'सत्यापित व्यक्तिगत नाम और अधिकृत मोबाइल नंबर' : 'Verified personal name and authorized mobile number';
  String get businessIdentitySub => isHindi ? 'फर्म का नाम, कॉर्पोरेट पता और GSTIN पहचान' : 'Registered firm name, HQ office address, and GSTIN identity';
  String get businessLocationTitle => isHindi ? 'व्यावसायिक स्थान (दुकान / गोदाम)' : 'Business Location (Shop / Warehouse / Godown)';
  String get businessLocationSub => isHindi ? 'वस्तु निरीक्षण और माल उठाने के लिए भौतिक व्यावसायिक पता' : 'Physical trade premises for commodity inspection and dispatch';
  String get bankDetailsTitle => isHindi ? 'बैंक विवरण' : 'Bank Details';
  String get bankDetailsSub => isHindi ? 'व्यापारिक भुगतानों के निपटान के लिए बैंक खाता' : 'Designated bank account for commodity trade settlements';
  String get myCommodityExpertiseTitle => isHindi ? 'मेरी कमोडिटी विशेषज्ञता' : 'My Commodity Expertise';
  String get commodityExpertiseSub => isHindi
      ? 'उन कृषि जिंसों का प्रबंधन करें जिनमें आप सक्रिय रूप से व्यापार करते हैं। लिस्टिंग बनाते समय ये पहले दिखाई देंगे।'
      : 'Manage agricultural commodities you specialize in. These appear first when posting lots for sale.';

  // Field Labels
  String get fullName => isHindi ? 'पूरा नाम' : 'Full Name';
  String get mobileNumber => isHindi ? 'मोबाइल नंबर' : 'Mobile Number';
  String get companyFirmName => isHindi ? 'कंपनी / फर्म का नाम' : 'Company / Firm Name';
  String get gstinLabel => isHindi ? 'GSTIN (15 अंक)' : 'GSTIN (15 Digits)';
  String get hqAddressLabel => isHindi ? 'कॉर्पोरेट कार्यालय का मुख्य पता' : 'Corporate Office HQ Address';
  String get locationNameLabel => isHindi ? 'स्थान / दुकान का नाम' : 'Location / Shop Name';
  String get streetAddressLabel => isHindi ? 'सड़क / मंडी / क्षेत्र का पता' : 'Street / Mandi / Area Address';
  String get localityLandmarkLabel => isHindi ? 'इलाका / लैंडमार्क' : 'Locality / Landmark';
  String get pinCodeLabel => isHindi ? 'पिन कोड (6 अंक)' : 'PIN Code (6 digits)';
  String get stateLabel => isHindi ? 'राज्य' : 'State';
  String get selectState => isHindi ? 'राज्य चुनें' : 'Select State';
  String get districtLabel => isHindi ? 'ज़िला' : 'District';
  String get selectDistrict => isHindi ? 'ज़िला चुनें' : 'Select District';
  String get accountHolderName => isHindi ? 'खाताधारक का नाम' : 'Account Holder Name';
  String get bankName => isHindi ? 'बैंक का नाम' : 'Bank Name';
  String get accountNumber => isHindi ? 'खाता संख्या' : 'Account Number';
  String get confirmAccountNumber => isHindi ? 'खाता संख्या की पुष्टि करें' : 'Confirm Account Number';
  String get ifscCode => isHindi ? 'IFSC कोड' : 'IFSC Code';
  String get branchNameOptional => isHindi ? 'शाखा का नाम (वैकल्पिक)' : 'Branch Name (Optional)';
  String get micrCode => isHindi ? 'MICR कोड' : 'MICR Code';
  String get micrCodeOptional => isHindi ? 'MICR कोड (वैकल्पिक, 9 अंक)' : 'MICR Code (Optional, 9 Digits)';
  String get scanCheque => isHindi ? 'चेक स्कैन करें' : 'Scan Cheque';
  String get scanChequeSubtitle => isHindi
      ? 'बैंक विवरण स्वतः भरने के लिए चेक की तस्वीर लें या गैलरी से चुनें।'
      : 'Photograph a cheque leaf or select from gallery to auto-fill bank details.';
  String get enterManually => isHindi ? 'मैन्युअल रूप से दर्ज करें' : 'Enter Manually';
  String get chequeReadingInProgress => isHindi ? 'चेक पढ़ा जा रहा है...' : 'Scanning cheque...';
  String get chequeExtractionFailed => isHindi ? 'चेक से जानकारी नहीं निकाली जा सकी' : 'Cheque text extraction failed';
  String get chequeExtractedSuccess => isHindi
      ? 'चेक से विवरण निकाले गए। कृपया पुष्टि करने से पहले समीक्षा करें।'
      : 'Cheque details extracted. Please review before confirming.';
  String get removeCheque => isHindi ? 'चेक हटाएं' : 'Remove Cheque';
  String get retakeCheque => isHindi ? 'दोबारा फ़ोटो लें' : 'Retake';
  String get replaceCheque => isHindi ? 'गैलरी से बदलें' : 'Replace';
  String get chequeSourceNotice => isHindi
      ? 'चेक से निकाले गए विवरण फॉर्म में भरे गए हैं। पुष्टि आवश्यक है।'
      : 'Details extracted from cheque leaf. Explicit confirmation required before saving.';
  String get bankPrivacyNotice => isHindi
      ? 'शून्य-गोपनीयता नीति (Zero-Secret Policy): बैंक विवरण केवल व्यापार निपटान के लिए सुरक्षित रूप से संग्रहीत किए जाते हैं और कभी तीसरे पक्ष के साथ साझा नहीं किए जाते हैं।'
      : 'Zero-Secret Policy: Bank details are stored securely for trade settlement purposes only and never shared with third parties.';

  // Field Hints
  String get fullNameHint => isHindi ? 'उदा. राजेश शर्मा' : 'e.g. Rajesh Sharma';
  String get mobileHint => isHindi ? '10 अंकों का मोबाइल नंबर' : '10-digit mobile number';
  String get companyHint => isHindi ? 'उदा. शर्मा एग्रो ट्रेडर्स' : 'e.g. Sharma Agro Traders';
  String get gstinHint => isHindi ? 'उदा. 08AABCB1234F1Z5' : 'e.g. 08AABCB1234F1Z5';
  String get hqAddressHint => isHindi ? 'उदा. प्लॉट 12, कृषि उपज मंडी' : 'e.g. Plot 12, Krishi Upaj Mandi';
  String get locationNameHint => isHindi ? 'उदा. मुख्य दुकान नं. 45' : 'e.g. Main Mandi Shop #45';
  String get streetAddressHint => isHindi ? 'दुकान संख्या, मंडी यार्ड या सड़क' : 'Shop No., Mandi Yard or Road';
  String get localityHint => isHindi ? 'उदा. अनाज मंडी के पास' : 'e.g. Near Grain Mandi Gate #2';
  String get pinCodeHint => isHindi ? '6 अंकों का पिन कोड' : '6-digit PIN code';
  String get accountHolderHint => isHindi ? 'बैंक रिकॉर्ड के अनुसार नाम' : 'Name as per bank records';
  String get bankNameHint => isHindi ? 'उदा. भारतीय स्टेट बैंक (SBI)' : 'e.g. State Bank of India';
  String get accountNumberHint => isHindi ? '9 से 18 अंकों की खाता संख्या' : '9 to 18 digits account number';
  String get ifscHint => isHindi ? 'उदा. SBIN0001234' : 'e.g. SBIN0001234';
  String get branchHint => isHindi ? 'उदा. कृषि मंडी शाखा' : 'e.g. Mandi Branch';
  String get micrHint => isHindi ? 'उदा. 110002001 (9 अंक)' : 'e.g. 110002001 (9 digits)';

  // GPS Location
  String get detectCurrentGps => isHindi ? 'वर्तमान GPS स्थान का पता लगाएं' : 'Detect Current GPS Location';
  String get gpsLocationDetected => isHindi ? 'GPS स्थान का पता लगाया गया' : 'GPS Location Detected';
  String get detectingGps => isHindi ? 'स्थान प्राप्त किया जा रहा है...' : 'Acquiring GPS coordinates...';

  // Commodity Expertise
  String get addCommodity => isHindi ? 'कमोडिटी जोड़ें' : 'Add Commodity';
  String get remove => isHindi ? 'हटाएं' : 'Remove';
  String get selectCommodityTitle => isHindi ? 'विशेषज्ञता कमोडिटी चुनें' : 'Select Expertise Commodity';
  String get noExpertiseSelected => isHindi
      ? 'अभी तक कोई कमोडिटी विशेषज्ञता नहीं चुनी गई है। नई बिक्री लॉट बनाते समय पसंदीदा कमोडिटी सबसे ऊपर दिखाई देंगी।'
      : 'No commodity expertise added yet. Adding commodities prioritizes them when posting sales.';
  String get suggestedFromInvoiceBadge => isHindi ? 'बिल से सुझाया गया' : 'Suggested from Invoice';
  String get searchCommodities => isHindi ? 'कमोडिटी खोजें...' : 'Search commodities...';

  // Validation Errors
  String get errBusinessNameRequired => isHindi ? 'व्यवसाय का नाम आवश्यक है।' : 'Business name is required.';
  String get errInvalidGstin => isHindi ? 'अमान्य GSTIN प्रारूप (उदा. 08AAAAA0000A1Z5)' : 'Invalid GSTIN format (e.g. 08AAAAA0000A1Z5)';
  String get errLocationNameRequired => isHindi ? 'स्थान / दुकान का नाम आवश्यक है।' : 'Location / Shop name is required.';
  String get errAddressRequired => isHindi ? 'सड़क / क्षेत्र का पता आवश्यक है।' : 'Street/area address is required.';
  String get errInvalidPin => isHindi ? 'कृपया 6 अंकों का मान्य पिन कोड दर्ज करें।' : 'Please enter a valid 6-digit PIN code.';
  String get errInvalidMobile => isHindi ? 'कृपया 10 अंकों का मान्य मोबाइल नंबर दर्ज करें।' : 'Please enter a valid 10-digit mobile number.';
  String get errAccountHolderRequired => isHindi ? 'खाताधारक का नाम आवश्यक है।' : 'Account holder name is required.';
  String get errBankNameRequired => isHindi ? 'बैंक का नाम आवश्यक है।' : 'Bank name is required.';
  String get errInvalidAccountNumber => isHindi ? 'खाता संख्या 9 से 18 अंकों की होनी चाहिए।' : 'Account number must be 9 to 18 digits.';
  String get errAccountsDoNotMatch => isHindi ? 'खाता संख्या मेल नहीं खाती।' : 'Account numbers do not match.';
  String get errInvalidIfsc => isHindi ? 'अमान्य IFSC कोड (उदा. SBIN0001234)' : 'Invalid IFSC code (e.g. SBIN0001234)';
  String get errInvalidMicr => isHindi ? 'अमान्य MICR कोड (9 अंक होने चाहिए)' : 'Invalid MICR code (must be 9 digits)';

  // Confirmation Sheet
  String get confirmationTitle => isHindi ? 'निकाली गई जानकारी की समीक्षा करें' : 'Review Extracted Details';
  String get confirmationSubtitle => isHindi ? 'प्रोफ़ाइल परिवर्तनों की समीक्षा करें' : 'Review Profile Changes';
  String get fieldColumn => isHindi ? 'फ़ील्ड' : 'Field';
  String get previousValueColumn => isHindi ? 'मौजूदा मान' : 'Current Value';
  String get newValueColumn => isHindi ? 'नया प्रस्तावित मान' : 'Proposed Value';
  String get notProvided => isHindi ? 'प्रदान नहीं किया गया' : 'Not provided';
  String get discardChanges => isHindi ? 'बदलाव रद्द करें' : 'Discard Changes';
  String get noChangesDetected => isHindi ? 'कोई परिवर्तन नहीं पाया गया।' : 'No changes detected.';

  // Save / Discard Dialogs & Snackbars
  String get profileSavedSuccess => isHindi ? 'प्रोफ़ाइल सफलतापूर्वक अपडेट की गई!' : 'Business profile updated successfully';
  String get profileSaveFailed => isHindi ? 'प्रोफ़ाइल सेव करने में विफल। ड्राफ्ट सुरक्षित है।' : 'Failed to save profile. Draft preserved.';
  String get discardDialogTitle => isHindi ? 'बदलाव रद्द करें?' : 'Discard changes?';
  String get discardDialogContent => isHindi
      ? 'आपके पास बिना सेव किए गए बदलाव हैं। क्या आप उन्हें रद्द करना चाहते हैं?'
      : 'You have unconfirmed modifications. Discard draft changes and exit edit mode?';
  String get continueEditing => isHindi ? 'संपादन जारी रखें' : 'Continue Editing';
  String get discard => isHindi ? 'रद्द करें' : 'Discard';

  // Permission & File Errors
  String get errCameraPermission => isHindi
      ? 'कैमरा अनुमति अस्वीकृत या कैप्चर अनुपलब्ध।'
      : 'Camera permission denied or capture unavailable.';
  String get errGalleryPermission => isHindi
      ? 'गैलरी अनुमति अस्वीकृत या चयन रद्द।'
      : 'Gallery permission denied or selection cancelled.';
  String get errFileSelection => isHindi
      ? 'दस्तावेज़ चयन रद्द या विफल हो गया।'
      : 'Document selection was cancelled or failed.';

  // OCR Intelligence & Conflict Notices
  String get pinConflictNotice => isHindi
      ? 'चेतावनी: निकाले गए पिन कोड और पते के राज्य में अंतर पाया गया। कृपया पुष्टि करें।'
      : 'Notice: Detected PIN code and address state conflict. Please verify.';
  String get mobileExtractedNotice => isHindi
      ? 'बिल से मोबाइल नंबर प्राप्त हुआ'
      : 'Mobile number extracted from invoice';
  String get pinResolvedNotice => isHindi
      ? 'पिन कोड से राज्य और जिला निकाला गया'
      : 'State & district auto-suggested from PIN code';
  String get sellerContact => isHindi ? 'विक्रेता संपर्क' : 'Seller Contact';
  String get buyerContact => isHindi ? 'खरीदार संपर्क' : 'Buyer Contact';

  // Additional Profile & Section Labels
  String get email => isHindi ? 'ईमेल' : 'Email';
  String get role => isHindi ? 'भूमिका' : 'Role';
  String get sellerRoleTitle => isHindi ? 'प्रमाणित जिंस विक्रेता' : 'Enterprise Commodity Seller';
  String get beneficiary => isHindi ? 'खाताधारक' : 'Beneficiary';
  String get bank => isHindi ? 'बैंक' : 'Bank';
  String get documentsAndInvoice => isHindi ? 'दस्तावेज़ और बिल' : 'Documents & Invoice';
  String get documentsSubtitle => isHindi
      ? 'त्वरित सत्यापन के लिए व्यावसायिक टैक्स इनवॉइस संलग्न करें'
      : 'Attach business tax invoice for fast-track verification';
  String get attachedInvoiceSubtitle => isHindi
      ? 'सत्यापित व्यवसाय इनवॉइस संलग्न है'
      : 'Verified Business Invoice Attached';
  String get attachBusinessInvoice => isHindi ? 'व्यवसाय का बिल संलग्न करें' : 'Attach Business Invoice';
  String get tradingDeskRules => isHindi ? 'ट्रेडिंग डेस्क के नियम' : 'Trading Desk Rules';
  String get tradingDeskRulesSub => isHindi ? 'प्रमुख दिशानिर्देश' : 'Key guidelines';
  String get appPreferences => isHindi ? 'ऐप प्राथमिकताएं' : 'App Preferences';
  String get appPreferencesSub => isHindi ? 'थीम, भाषा, अभिगम्यता' : 'Theme, language, accessibility';
  String get appPreferencesDesc => isHindi
      ? 'थीम, भाषा, फ़ॉन्ट आकार और उच्च-कंट्रास्ट विकल्प सेटिंग्स में प्रबंधित किए जाते हैं।'
      : 'Theme, language, font size and high-contrast options are managed in Settings.';
  String get openSettings => isHindi ? 'सेटिंग्स खोलें' : 'Open Settings';
  String get inspect => isHindi ? 'जांचें' : 'Inspect';
  String get verifiedBadge => isHindi ? 'सत्यापित' : 'Verified';
  String get unverifiedBadge => isHindi ? 'असत्यापित' : 'Unverified';
  String get pendingVerificationBadge => isHindi ? 'सत्यापन लंबित' : 'Pending Desk Verification';
  String get gpsLinked => isHindi ? 'GPS लिंक' : 'GPS Linked';
  String get signOut => isHindi ? 'लॉग आउट करें' : 'Sign Out of Seller Desk';
  String get tradingDeskRulesContent => isHindi
      ? '1. सभी कमोडिटी बिक्री विशेष रूप से अधिकृत क्षेत्रीय दलालों के माध्यम से की जाती है।\n'
        '2. काउंटरपार्टी शील्ड नीतियों के तहत सीधे खरीदार संचार और निर्देशिका खोज निषिद्ध है।\n'
        '3. पंजीकृत गोदाम स्थानों पर विक्रेता भौतिक लोडिंग तत्परता के लिए जिम्मेदार हैं।'
      : '1. All commodity sales are mediated exclusively through authorized regional brokers.\n'
        '2. Direct buyer communications and directory searches are prohibited under counterparty shield policies.\n'
        '3. Sellers are responsible for physical loading readiness at registered warehouse locations.';
  String get draftDocument => isHindi ? 'ड्राफ्ट दस्तावेज़' : 'Draft Document';
  String get serverVerifiedDocument => isHindi ? 'सर्वर सत्यापित दस्तावेज़' : 'Server Verified Document';
}
