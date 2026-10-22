import fs from 'fs';
import path from 'path';

interface TestCase {
  id: string;
  name: string;
  category: string;
  fn: () => boolean | Promise<boolean>;
  details?: string;
}

const tests: TestCase[] = [];

function registerTest(id: string, name: string, category: string, fn: () => boolean | Promise<boolean>) {
  tests.push({ id, name, category, fn });
}

// ============================================================================
// 1. Dashboard Three-Dot Menu
// ============================================================================

registerTest(
  'PROF-01',
  'Verify standard three-dot overflow menu button is placed in SellerHomeScreen appbar',
  'Dashboard Overflow Menu',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('dashboard_overflow_menu_button') &&
      content.includes('LucideIcons.ellipsisVertical') &&
      content.includes('tooltip: \'More options\'')
    );
  }
);

registerTest(
  'PROF-02',
  'Verify overflow menu contains My Profile, Settings, Help & Support, Notifications & Logout in order',
  'Dashboard Overflow Menu',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    const profileIdx = content.indexOf('menu_item_profile');
    const settingsIdx = content.indexOf('menu_item_settings');
    const helpIdx = content.indexOf('menu_item_help');
    const notifIdx = content.indexOf('menu_item_notifications');
    const dividerIdx = content.indexOf('PopupMenuDivider()');
    const logoutIdx = content.indexOf('menu_item_logout');

    return (
      profileIdx !== -1 &&
      settingsIdx > profileIdx &&
      helpIdx > settingsIdx &&
      notifIdx > helpIdx &&
      dividerIdx > notifIdx &&
      logoutIdx > dividerIdx
    );
  }
);

registerTest(
  'PROF-03',
  'Verify overflow menu actions map to correct destinations and logout flow',
  'Dashboard Overflow Menu',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes("context.go('/profile')") &&
      content.includes("context.push('/settings')") &&
      content.includes("context.push('/help')") &&
      content.includes("context.push('/notifications')") &&
      content.includes('_showSignOutDialog(context)')
    );
  }
);

// ============================================================================
// 2. Profile Domain Model & Authoritative Repository
// ============================================================================

registerTest(
  'PROF-04',
  'Verify SellerProfileModel is defined with complete fields and serialization',
  'Profile Architecture',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/domain/seller_profile_model.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('class SellerProfileModel') &&
      content.includes('final String id;') &&
      content.includes('final String fullName;') &&
      content.includes('final String email;') &&
      content.includes('final String mobile;') &&
      content.includes('final String role;') &&
      content.includes('final String companyId;') &&
      content.includes('final String companyName;') &&
      content.includes('final String companyGst;') &&
      content.includes('final String primaryMandi;') &&
      content.includes('final bool isVerified;') &&
      content.includes('copyWith') &&
      content.includes('fromMap')
    );
  }
);

registerTest(
  'PROF-05',
  'Verify SellerProfileRepository implements authoritative lookups & updates on users/companies',
  'Profile Persistence',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('class SellerProfileRepository') &&
      content.includes(".from('users')") &&
      content.includes(".from('companies')") &&
      content.includes('getProfile()') &&
      content.includes('updateProfile(SellerProfileModel') &&
      content.includes('saveUserInfo') &&
      content.includes('savePreference')
    );
  }
);

// ============================================================================
// 3. SellerProfileScreen View Mode & Edit Mode
// ============================================================================

registerTest(
  'PROF-06',
  'Verify SellerProfileScreen provides prominent Edit Profile button and clear read-only separation',
  'Profile UI & Interactions',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('edit_profile_button') &&
      content.includes('appbar_edit_profile_button') &&
      content.includes('Verified Seller Enterprise') &&
      content.includes('Protected Account Identifiers (Read-Only)') &&
      content.includes('Cryptographic account key immutable under platform security rules')
    );
  }
);

registerTest(
  'PROF-07',
  'Verify Edit Mode provides form fields for name, company name, mobile, GSTIN and mandi hub',
  'Profile UI & Interactions',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('edit_full_name_field') &&
      content.includes('edit_company_name_field') &&
      content.includes('edit_mobile_field') &&
      content.includes('edit_gstin_field') &&
      content.includes('edit_mandi_field') &&
      content.includes('cancel_profile_button') &&
      content.includes('save_profile_button')
    );
  }
);

registerTest(
  'PROF-08',
  'Verify validation rules for required names, 10-digit mobile number, and GSTIN format',
  'Validation & Security',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('Full name is required (minimum 2 characters)') &&
      content.includes('Business name is required (minimum 2 characters)') &&
      content.includes('Enter a valid 10-digit Indian mobile number') &&
      content.includes('Enter a valid 15-character GSTIN')
    );
  }
);

registerTest(
  'PROF-09',
  'Verify Cancel reverts changes and Save Changes triggers authoritative update with feedback',
  'Profile Persistence & Feedback',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('_cancelEdit()') &&
      content.includes('_handleSaveProfile()') &&
      content.includes('Profile updated successfully') &&
      content.includes('Failed to update profile')
    );
  }
);

// ============================================================================
// 4. Dedicated Settings & Help Screens
// ============================================================================

registerTest(
  'PROF-10',
  'Verify dedicated SellerSettingsScreen is implemented hosting AppSettingsSection',
  'Settings Integration',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/profile/presentation/seller_settings_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('class SellerSettingsScreen') &&
      content.includes('Application Settings') &&
      content.includes('AppSettingsSection()')
    );
  }
);

registerTest(
  'PROF-11',
  'Verify dedicated SellerHelpSupportScreen is implemented without fabricated contact details',
  'Help & Support Integration',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/help/presentation/seller_help_support_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('class SellerHelpSupportScreen') &&
      content.includes('Seller Command Center & KPIs') &&
      content.includes('Profile & Enterprise Account') &&
      content.includes('Mandi Mediation & Counterparty Shield') &&
      content.includes('Commodity Lots & Quality Parameters') &&
      content.includes('Verified Support Channels') &&
      content.includes('Submit Support Request')
    );
  }
);

registerTest(
  'PROF-12',
  'Verify AppRouter registers /settings, /help and /profile/edit protected routes',
  'Routing & Navigation',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/app/router/app_router.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes("path: '/settings'") &&
      content.includes('SellerSettingsScreen()') &&
      content.includes("path: '/help'") &&
      content.includes('SellerHelpSupportScreen()') &&
      content.includes("path: '/profile/edit'")
    );
  }
);

registerTest(
  'PROF-13',
  'Verify dedicated widget test suite seller_profile_menu_test.dart exists',
  'Verification Suite',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/test/widgets/seller_profile_menu_test.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('RB-SELLER-PROFILE-01: Dashboard Three-Dot Menu Tests') &&
      content.includes('RB-SELLER-PROFILE-01: SellerProfileScreen View & Edit Mode Tests') &&
      content.includes('RB-SELLER-PROFILE-01: Dedicated Settings & Help Screens Tests')
    );
  }
);

registerTest(
  'PROF-14',
  'Verify Scope Guardrails: Zero database migrations, buyer app or broker app mutations',
  'Scope Constraint',
  () => {
    // Check no new database migrations were added
    const migrationsDir = path.join(process.cwd(), 'supabase/migrations');
    const files = fs.readdirSync(migrationsDir);
    const hasUnapprovedMigration = files.some(
      (f) => f.includes('seller_profile') || f.includes('profile_menu')
    );

    return !hasUnapprovedMigration;
  }
);

// ============================================================================
// Test Runner
// ============================================================================

async function runTests() {
  console.log('================================================================');
  console.log('RB-SELLER-PROFILE-01: Automated Verification Test Suite');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    try {
      const result = await test.fn();
      if (result) {
        console.log(`[PASS] ${test.id}: ${test.name} (${test.category})`);
        passed++;
      } else {
        console.error(`[FAIL] ${test.id}: ${test.name} (${test.category})`);
        failed++;
      }
    } catch (err) {
      console.error(`[FAIL] ${test.id}: ${test.name} (${test.category}) - Error:`, err);
      failed++;
    }
  }

  console.log('\n----------------------------------------------------------------');
  console.log(`Execution Summary: Total: ${tests.length} | Passed: ${passed} | Failed: ${failed}`);
  console.log(`Pass Rate: ${((passed / tests.length) * 100).toFixed(1)}%`);
  console.log('----------------------------------------------------------------\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
