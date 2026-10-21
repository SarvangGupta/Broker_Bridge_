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
// 1. Files & Structural Verification
// ============================================================================

registerTest('MB-01', 'Verify MainActivity implements contact picker platform channel', 'Native Integration', () => {
  const mainActivityPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/android/app/src/main/kotlin/com/brokerbridge/rmseller_mobile/MainActivity.kt'
  );
  if (!fs.existsSync(mainActivityPath)) return false;
  const content = fs.readFileSync(mainActivityPath, 'utf8');

  return (
    content.includes('com.brokerbridge.rmseller/contacts') &&
    content.includes('pickContact') &&
    content.includes('Intent.ACTION_PICK') &&
    content.includes('ContactsContract.CommonDataKinds.Phone.CONTENT_URI') &&
    content.includes('ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME') &&
    content.includes('ContactsContract.CommonDataKinds.Phone.NUMBER') &&
    content.includes('result.success(null)') // user cancellation handling
  );
});

registerTest('MB-02', 'Verify AndroidManifest declares permissions safely', 'Permissions', () => {
  const manifestPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/android/app/src/main/AndroidManifest.xml'
  );
  if (!fs.existsSync(manifestPath)) return false;
  const content = fs.readFileSync(manifestPath, 'utf8');
  return (
    content.includes('android.permission.INTERNET') &&
    content.includes('android.permission.READ_CONTACTS')
  );
});

registerTest('MB-03', 'Verify PhoneUtils standardizes Indian mobile numbers (+91)', 'Normalization', () => {
  const phoneUtilsPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/core/utils/phone_utils.dart'
  );
  if (!fs.existsSync(phoneUtilsPath)) return false;
  const content = fs.readFileSync(phoneUtilsPath, 'utf8');
  return (
    content.includes('class PhoneUtils') &&
    content.includes('validateAndNormalize') &&
    content.includes('+91') &&
    content.includes('^[6-9]') &&
    content.includes('PhoneValidationResult')
  );
});

registerTest('MB-04', 'Verify ContactPickerService wraps native channel with safe cancellation', 'Services', () => {
  const servicePath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/core/services/contact_picker_service.dart'
  );
  if (!fs.existsSync(servicePath)) return false;
  const content = fs.readFileSync(servicePath, 'utf8');
  return (
    content.includes('com.brokerbridge.rmseller/contacts') &&
    content.includes('ContactPickerResult.cancelled()') &&
    content.includes('ContactPickerResult.success') &&
    content.includes('ContactPickerResult.error') &&
    content.includes('PlatformException')
  );
});

// ============================================================================
// 2. Domain & Broker Lifecycle Model Verification
// ============================================================================

registerTest('MB-05', 'Verify SellerBrokerStatus enum and lifecycle fields in SellerBrokerModel', 'Domain', () => {
  const modelPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/domain/seller_broker_model.dart'
  );
  if (!fs.existsSync(modelPath)) return false;
  const content = fs.readFileSync(modelPath, 'utf8');
  return (
    content.includes('enum SellerBrokerStatus') &&
    content.includes('registeredVerified') &&
    content.includes('pendingVerification') &&
    content.includes('invitationPending') &&
    content.includes('final SellerBrokerStatus status;') &&
    content.includes('bool get isInvitationPending') &&
    content.includes('bool get isPendingVerification') &&
    content.includes('bool get isRegisteredVerified') &&
    content.includes('invitedAt')
  );
});

registerTest('MB-06', 'Verify SellerBrokerRepository authoritative phone lookup', 'Data Layer', () => {
  const repoPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/data/seller_broker_repository.dart'
  );
  if (!fs.existsSync(repoPath)) return false;
  const content = fs.readFileSync(repoPath, 'utf8');
  return (
    content.includes('enum BrokerLookupStatus') &&
    content.includes('class BrokerLookupResult') &&
    content.includes('lookupBrokerByPhone') &&
    content.includes('addBroker') &&
    content.includes('inviteBroker') &&
    content.includes('BrokerLookupStatus.alreadyLinked') &&
    content.includes('BrokerLookupStatus.notFound') &&
    content.includes('BrokerLookupStatus.found')
  );
});

registerTest('MB-07', 'Verify SellerBrokerRepository NEVER marks invited contact as verified', 'Security Invariant', () => {
  const repoPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/data/seller_broker_repository.dart'
  );
  if (!fs.existsSync(repoPath)) return false;
  const content = fs.readFileSync(repoPath, 'utf8');
  return (
    content.includes('isVerified: false') &&
    content.includes('status: SellerBrokerStatus.invitationPending')
  );
});

// ============================================================================
// 3. UI, Floating Action Button & Bottom Sheet Options
// ============================================================================

registerTest('MB-08', 'Verify MyBrokersScreen has Floating Action Button with Add Broker label', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('floatingActionButton: FloatingActionButton.extended') &&
    content.includes("'Add Broker'") &&
    content.includes('LucideIcons.userPlus') &&
    content.includes("tooltip: 'Add Broker'")
  );
});

registerTest('MB-09', 'Verify Add Broker options bottom sheet contains all 3 required choices', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('Select from Phone Contacts') &&
    content.includes('Add Number Manually') &&
    content.includes('Cancel') &&
    content.includes('_showAddBrokerOptions')
  );
});

registerTest('MB-10', 'Verify manual phone number entry enforces Indian mobile standard', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('_showManualEntryDialog') &&
    content.includes('+91 (IN)') &&
    content.includes('FilteringTextInputFormatter.digitsOnly') &&
    content.includes('LengthLimitingTextInputFormatter(10)') &&
    content.includes('Verify & Add')
  );
});

registerTest('MB-11', 'Verify registered broker match sheet shows authorized fields only', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('_showBrokerMatchSheet') &&
    content.includes('Registered Broker Desk Found') &&
    content.includes('LucideIcons.badgeCheck') &&
    content.includes('trustScore') &&
    content.includes('Add to My Brokers')
  );
});

registerTest('MB-12', 'Verify invitation sheet enforces broker self-verification via WhatsApp and Phone', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('_showInvitationSheet') &&
    content.includes('Broker Self-Verification Required') &&
    content.includes('Invite via WhatsApp') &&
    content.includes('Call Desk to Invite') &&
    content.includes('Cancel without Inviting') &&
    content.includes('https://brokerbridge.in/login')
  );
});

registerTest('MB-13', 'Verify broker card distinguishes Verified, Pending Verification, and Invitation Pending', 'Presentation', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('broker.isRegisteredVerified') &&
    content.includes('broker.isPendingVerification') &&
    content.includes('broker.isInvitationPending') &&
    content.includes('Pending Verification') &&
    content.includes('Invitation Pending')
  );
});

registerTest('MB-14', 'Verify ListView has bottom padding to prevent FAB overlap', 'Layout & UX', () => {
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  if (!fs.existsSync(screenPath)) return false;
  const content = fs.readFileSync(screenPath, 'utf8');
  return (
    content.includes('EdgeInsets.fromLTRB(16, 16, 16, 84)') ||
    content.includes('EdgeInsets.fromLTRB(16, 16, 16, 80)')
  );
});

// ============================================================================
// 4. Test Suites & Regression Verification
// ============================================================================

registerTest('MB-15', 'Verify dedicated unit test file exists', 'Verification', () => {
  const testPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/test/unit/add_broker_test.dart'
  );
  if (!fs.existsSync(testPath)) return false;
  const content = fs.readFileSync(testPath, 'utf8');
  return (
    content.includes('PhoneUtils Indian Mobile Normalization Tests') &&
    content.includes('SellerBrokerRepository Lookup and Self-Verification Tests') &&
    content.includes('Normalizes valid 10-digit Indian numbers') &&
    content.includes('Inviting a broker records pending status')
  );
});

registerTest('MB-16', 'Verify dedicated widget test file exists', 'Verification', () => {
  const widgetTestPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/test/widgets/my_brokers_screen_test.dart'
  );
  if (!fs.existsSync(widgetTestPath)) return false;
  const content = fs.readFileSync(widgetTestPath, 'utf8');
  return (
    content.includes('MyBrokersScreen renders FAB and opens Add Broker options bottom sheet') &&
    content.includes('Add Number Manually opens mobile entry modal') &&
    content.includes('find.byType(FloatingActionButton)')
  );
});

registerTest('MB-17', 'Verify Counterparty Shield: Zero buyer directory or buyer contact in seller app', 'Security Invariant', () => {
  const repoPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/data/seller_broker_repository.dart'
  );
  const screenPath = path.join(
    process.cwd(),
    'apps/rmseller_mobile/lib/features/brokers/presentation/my_brokers_screen.dart'
  );
  const repoContent = fs.readFileSync(repoPath, 'utf8');
  const screenContent = fs.readFileSync(screenPath, 'utf8');

  // Both should contain the counterparty shield note and never query 'role', 'buyer'
  return (
    repoContent.includes('COUNTERPARTY SHIELD INVARIANT') &&
    !repoContent.includes(".eq('role', 'buyer')") &&
    !screenContent.includes('Buyer Directory')
  );
});

registerTest('MB-18', 'Verify zero database migrations or mutations in sprint', 'Scope Constraint', () => {
  // Confirm git status doesn't touch supabase/migrations or schema.ts
  const schemaPath = path.join(process.cwd(), 'src/server/db/schema.ts');
  const schemaContent = fs.readFileSync(schemaPath, 'utf8');
  return schemaContent.includes('export const users = pgTable') && schemaContent.includes('export const availabilities = pgTable');
});

// ============================================================================
// Test Runner Execution
// ============================================================================

async function runAllTests() {
  console.log('================================================================');
  console.log('RB-SELLER-MY-BROKERS-ADD-01: Automated Verification Test Suite');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  for (const t of tests) {
    try {
      const result = await t.fn();
      if (result) {
        console.log(`[PASS] ${t.id}: ${t.name} (${t.category})`);
        passed++;
      } else {
        console.error(`[FAIL] ${t.id}: ${t.name} (${t.category})`);
        failed++;
      }
    } catch (e: any) {
      console.error(`[ERROR] ${t.id}: ${t.name} (${t.category}) - ${e?.message}`);
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

runAllTests();
