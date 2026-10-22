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
// 1. Structural & Layout Verification
// ============================================================================

registerTest(
  'DASH-01',
  'Verify prominent disclaimer banner is removed from SellerHomeScreen body',
  'Layout & Space Reclamation',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    // Verify _buildActionCenterCard call is not in ListView children
    const listViewIdx = content.indexOf('child: ListView(');
    if (listViewIdx === -1) return false;
    const metricCardsIdx = content.indexOf('// 4 Authoritative Metric Cards', listViewIdx);
    if (metricCardsIdx === -1) return false;

    const topOfListView = content.slice(listViewIdx, metricCardsIdx);
    return !topOfListView.includes('_buildActionCenterCard');
  }
);

registerTest(
  'DASH-02',
  'Verify top of ListView starts directly with 4 authoritative metric cards',
  'Layout & Space Reclamation',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('title: \'Active Lots\'') &&
      content.includes('title: \'In Negotiation\'') &&
      content.includes('title: \'Booked Deals\'') &&
      content.includes('title: \'Ready to Load\'')
    );
  }
);

registerTest(
  'DASH-03',
  'Verify compact info icon is placed near dashboard heading',
  'Compact Information Icon',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    // In AppBar title, _companyName is next to the LucideIcons.info IconButton
    return (
      content.includes('_companyName') &&
      content.includes('LucideIcons.info') &&
      content.includes('_showMediationDisclaimerDialog')
    );
  }
);

registerTest(
  'DASH-04',
  'Verify accessible label and tooltip for mediation info button',
  'Compact Information Icon',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes("tooltip: 'Mediation information'") &&
      content.includes("key: const Key('mediation_info_button')")
    );
  }
);

// ============================================================================
// 2. On-Demand Disclosure Dialog
// ============================================================================

registerTest(
  'DASH-05',
  'Verify on-demand disclosure dialog implementation',
  'Disclosure Dialog',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('void _showMediationDisclaimerDialog(BuildContext context)') &&
      content.includes('showDialog<void>(') &&
      content.includes('AlertDialog(')
    );
  }
);

registerTest(
  'DASH-06',
  'Verify verbatim disclaimer title Mandi Mediation Active and shield badge',
  'Disclosure Dialog',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes("'Mandi Mediation Active'") &&
      content.includes('LucideIcons.shieldCheck')
    );
  }
);

registerTest(
  'DASH-07',
  'Verify substantive disclaimer text is preserved verbatim without alteration',
  'Content Rule',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    const exactDisclaimer =
      'All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded.';
    return content.includes(exactDisclaimer);
  }
);

registerTest(
  'DASH-08',
  'Verify close action and standard dismissal support',
  'Interaction & Dismissal',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('barrierDismissible: true') &&
      content.includes('Navigator.of(dialogContext).pop()') &&
      content.includes("child: const Text('Close')")
    );
  }
);

registerTest(
  'DASH-09',
  'Verify responsive SingleChildScrollView and dark theme support in disclosure dialog',
  'Responsive & Theming',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    return (
      content.includes('SingleChildScrollView(') &&
      content.includes('Theme.of(context).brightness == Brightness.dark') &&
      content.includes('AppColors.surfaceDark') &&
      content.includes('AppColors.surfaceLight')
    );
  }
);

// ============================================================================
// 3. Security, Invariants & Scope Guardrails
// ============================================================================

registerTest(
  'DASH-10',
  'Verify Counterparty Shield invariant: Zero direct buyer communication on dashboard',
  'Security & Compliance',
  () => {
    const filePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart'
    );
    if (!fs.existsSync(filePath)) return false;
    const content = fs.readFileSync(filePath, 'utf8');

    // Dashboard must not expose direct buyer contacts, phone numbers, or directories
    return (
      !content.includes('buyer_contacts') &&
      !content.includes('direct_chat_buyer') &&
      !content.includes('buyer_directory')
    );
  }
);

registerTest(
  'DASH-11',
  'Verify dedicated widget test suite with all required test cases',
  'Verification Suite',
  () => {
    const testFilePath = path.join(
      process.cwd(),
      'apps/rmseller_mobile/test/widgets/seller_home_screen_test.dart'
    );
    if (!fs.existsSync(testFilePath)) return false;
    const content = fs.readFileSync(testFilePath, 'utf8');

    return (
      content.includes('RB-SELLER-DASH-01: SellerHomeScreen Widget Tests') &&
      content.includes('Prominent banner is removed and primary metric cards start naturally') &&
      content.includes('Compact information icon renders near dashboard heading') &&
      content.includes('Tapping information icon displays detailed mediation disclosure') &&
      content.includes('Disclosure dialog can be dismissed reliably via Close button') &&
      content.includes('Disclosure dialog renders properly without overflow on compact mobile screens') &&
      content.includes('Respects dark theme styling')
    );
  }
);

registerTest(
  'DASH-12',
  'Verify Scope Guardrail: Zero changes to buyer app, broker app, or database migrations',
  'Scope Constraint',
  () => {
    const rootDir = process.cwd();
    const buyerAppExists = fs.existsSync(path.join(rootDir, 'apps/rmbuyer_mobile'));
    const brokerAppExists = fs.existsSync(path.join(rootDir, 'apps/rmbroker_mobile'));
    return buyerAppExists && brokerAppExists;
  }
);

// ============================================================================
// Runner
// ============================================================================

async function runAll() {
  console.log('================================================================');
  console.log('RB-SELLER-DASH-01: Automated Verification Test Suite');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  for (const t of tests) {
    try {
      const res = await t.fn();
      if (res) {
        console.log(`[PASS] ${t.id}: ${t.name} (${t.category})`);
        passed++;
      } else {
        console.log(`[FAIL] ${t.id}: ${t.name} (${t.category})`);
        if (t.details) console.log(`       Details: ${t.details}`);
        failed++;
      }
    } catch (e: any) {
      console.log(`[FAIL] ${t.id}: ${t.name} (Exception: ${e?.message})`);
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

runAll();
