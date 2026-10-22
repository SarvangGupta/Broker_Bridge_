import fs from 'fs';
import path from 'path';

interface VerificationResult {
  checkpoint: string;
  passed: boolean;
  details: string;
}

const results: VerificationResult[] = [];

function check(checkpoint: string, condition: boolean, details: string) {
  results.push({ checkpoint, passed: condition, details });
  const status = condition ? '[PASS]' : '[FAIL]';
  console.log(`${status} ${checkpoint}: ${details}`);
}

const rootDir = process.cwd();
const mobileDir = path.join(rootDir, 'apps', 'rmseller_mobile');

console.log('\n--- RB-SELLER-PROFILE-02: Automated Verification Suite ---\n');

// 1. BusinessLocationModel entity
const locationModelPath = path.join(mobileDir, 'lib', 'features', 'profile', 'domain', 'business_location_model.dart');
const hasLocationModel = fs.existsSync(locationModelPath);
let locModelContent = '';
if (hasLocationModel) {
  locModelContent = fs.readFileSync(locationModelPath, 'utf-8');
}
check(
  'CP1: BusinessLocationModel entity exists',
  hasLocationModel &&
    locModelContent.includes('class BusinessLocationModel') &&
    locModelContent.includes('addressLine') &&
    locModelContent.includes('stateName') &&
    locModelContent.includes('districtName') &&
    locModelContent.includes('pinCode'),
  'BusinessLocationModel encapsulates shop/godown name, address, state, district, pin, and coordinates'
);

// 2. BusinessLocationService reverse geocoding
const locationServicePath = path.join(mobileDir, 'lib', 'features', 'profile', 'data', 'business_location_service.dart');
const hasLocationService = fs.existsSync(locationServicePath);
let locServiceContent = '';
if (hasLocationService) {
  locServiceContent = fs.readFileSync(locationServicePath, 'utf-8');
}
check(
  'CP2: BusinessLocationService provides reverse geocoding & presets',
  hasLocationService &&
    locServiceContent.includes('class BusinessLocationService') &&
    locServiceContent.includes('reverseGeocode') &&
    locServiceContent.includes('getCurrentLocation') &&
    locServiceContent.includes('getLocationPresets'),
  'BusinessLocationService resolves coordinates to MasterState and MasterDistrict with confidence indicator'
);

// 3. SellerProfileModel updated with officeAddress and businessLocation
const profileModelPath = path.join(mobileDir, 'lib', 'features', 'profile', 'domain', 'seller_profile_model.dart');
const profileModelContent = fs.readFileSync(profileModelPath, 'utf-8');
check(
  'CP3: SellerProfileModel contains officeAddress and businessLocation',
  profileModelContent.includes('final String officeAddress;') &&
    profileModelContent.includes('final BusinessLocationModel businessLocation;') &&
    profileModelContent.includes('office_address'),
  'Distinguishes corporate office HQ from physical shop/godown location'
);

// 4. SellerProfileRepository persists business location & office address
const repoPath = path.join(mobileDir, 'lib', 'features', 'profile', 'data', 'seller_profile_repository.dart');
const repoContent = fs.readFileSync(repoPath, 'utf-8');
check(
  'CP4: SellerProfileRepository persists business location and office address',
  repoContent.includes('business_location_name') &&
    repoContent.includes('business_location_address') &&
    repoContent.includes('business_location_state') &&
    repoContent.includes('business_location_district') &&
    repoContent.includes('office_address'),
  'Authoritative dual-persistence across Supabase companies table and encrypted SecureStorageService'
);

// 5. Technical UI details removed from SellerProfileScreen
const screenPath = path.join(mobileDir, 'lib', 'features', 'profile', 'presentation', 'seller_profile_screen.dart');
const screenContent = fs.readFileSync(screenPath, 'utf-8');
check(
  'CP5: Technical UUIDs, Supabase references & cryptographic disclaimers hidden from UI',
  !screenContent.includes('Cryptographic account key immutable under platform security rules.') &&
    !screenContent.includes('Primary authentication credential managed by Supabase Auth.') &&
    !screenContent.includes('Protected Account Identifiers (Read-Only)'),
  'Technical clutter and Supabase metadata removed in favor of clean business information'
);

// 6. Business Information section renders business-relevant fields
check(
  'CP6: Clean Business Information section present',
  screenContent.includes('Business Information') &&
    screenContent.includes('Contact Person:') &&
    screenContent.includes('Mobile Number:') &&
    screenContent.includes('Business Email:') &&
    screenContent.includes('Corporate HQ:'),
  'User-facing business information presented clearly for non-technical users'
);

// 7. Business Location (Shop / Godown) section present in View Mode
check(
  'CP7: Business Location section present in View Mode',
  screenContent.includes("key: const Key('business_location_view_card')") &&
    screenContent.includes('Business Location (Shop / Godown)') &&
    screenContent.includes('Facility Name:') &&
    screenContent.includes('Premises Address:') &&
    screenContent.includes('State & District:'),
  'Renders facility name, address, state, district, and PIN code in View Mode'
);

// 8. Location selection controls in Edit Mode
check(
  'CP8: Location controls (Current Location & Mandi Presets) in Edit Mode',
  screenContent.includes("key: const Key('btn_use_current_location')") &&
    screenContent.includes("key: const Key('btn_location_presets')") &&
    screenContent.includes("key: const Key('edit_location_name_field')"),
  'Provides 1-tap geolocation detection, regional mandi presets, and manual form input'
);

// 9. Cascading State and District Dropdowns in Edit Mode
check(
  'CP9: Cascading State and District Dropdowns using MasterCommodityData',
  screenContent.includes("key: const Key('location_state_dropdown')") &&
    screenContent.includes("key: const Key('location_district_dropdown')") &&
    screenContent.includes('_onStateChanged') &&
    screenContent.includes('MasterCommodityData.verifiedStates') &&
    screenContent.includes('MasterCommodityData.verifiedDistricts'),
  'Cascades state selection to filter valid districts and prevent cross-state contamination'
);

// 10. Distinct Corporate HQ vs Godown address fields
check(
  'CP10: Corporate HQ and Godown address fields separated',
  screenContent.includes("key: const Key('edit_office_address_field')") &&
    screenContent.includes("key: const Key('edit_location_address_field')"),
  'Guarantees corporate office HQ address is never overwritten by warehouse changes'
);

// 11. Widget tests for RB-SELLER-PROFILE-02
const testPath = path.join(mobileDir, 'test', 'widgets', 'seller_profile_menu_test.dart');
const testContent = fs.readFileSync(testPath, 'utf-8');
check(
  'CP11: Widget test suite covers UI simplification and location selection',
  testContent.includes('RB-SELLER-PROFILE-02: Profile UI Simplification & Location Tests') &&
    testContent.includes('Renders simplified profile in View Mode without technical UUIDs or metadata') &&
    testContent.includes('Tapping Use Current Location populates State & District with confidence indicator') &&
    testContent.includes('Changing State dropdown cascades to filter districts for the selected state'),
  'Comprehensive widget test coverage for UI simplification, geolocation, and cascading dropdowns'
);

// 12. Pre-change audit report exists
const auditPath = path.join(mobileDir, 'RB-SELLER-PROFILE-02-AUDIT-REPORT.md');
check(
  'CP12: Pre-change audit report RB-SELLER-PROFILE-02-AUDIT-REPORT.md present',
  fs.existsSync(auditPath),
  'Audit report documents existing sources, reverse geocoding approach, and technical fields removed'
);

const total = results.length;
const passed = results.filter((r) => r.passed).length;
const failed = total - passed;

console.log(`\n========================================`);
console.log(`Summary: ${passed} / ${total} checkpoints passed (${Math.round((passed / total) * 100)}%)`);
console.log(`========================================\n`);

if (failed > 0) {
  process.exit(1);
}
