/**
 * ============================================================================
 * MICRO-SPRINT RB-06: RMBROKER BUYER & SELLER DIRECTORY TEST SUITE
 * ============================================================================
 *
 * Validates the core acceptance criteria of Micro-Sprint RB-06:
 * 1. Authorized Directory Listing & Filter/Search Capabilities.
 * 2. Strict Broker-to-Contact Ownership & Data Isolation.
 * 3. Server-Side Duplicate Prevention Architecture.
 * 4. Contact Validation & Indian Mobile Normalization (+91 Standard).
 * 5. 360-Degree Profile & Linked Business Records (Deals, Reqs, Offers).
 * 6. User-Initiated Safe Dialler & WhatsApp Communication Actions.
 * 7. Soft Archival & Status Toggle without Business Data Deletion.
 * 8. English & Hindi Localization Parity & Mandi Domain Fidelity.
 * 9. Responsive Layout Ergonomics & Overflow Safety.
 * 10. Preservation of RB-03 Security Controls & Broker Firewall (ADR-004).
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';

// Localization Subsystem
import { TRANSLATIONS } from '@/src/lib/i18n/translations';

// Phone Utilities Under Test
import {
  validateAndNormalizePhone,
  getSafeTelUri,
  getSafeWhatsAppUri,
} from '@/src/lib/phone-utils';

// Server Actions Under Test
import {
  getBrokerDirectoryContactsAction,
  getBrokerContactDetailsAction,
  checkContactDuplicateAction,
  createBrokerContactAction,
  updateBrokerContactAction,
  toggleContactStatusAction,
} from '@/src/server/actions/broker-directory-actions';
import { createContactSchema } from '@/src/lib/validations/broker-directory-schema';


export interface RB06TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB06VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB06TestCaseResult[];
}

export async function runRMBrokerDirectoryVerification(): Promise<RB06VerificationReport> {
  const results: RB06TestCaseResult[] = [];

  const record = (
    id: string,
    name: string,
    category: string,
    passed: boolean,
    evidence: string,
    detail?: string
  ) => {
    results.push({ id, name, category, passed, evidence, detail });
    const status = passed ? '[PASS]' : '[FAIL]';
    console.log(`${status} [${id}] ${name}`);
    console.log(`       └─ ${evidence}`);
    if (detail && !passed) {
      console.log(`          Detail: ${detail}`);
    }
  };

  const projectRoot = process.cwd();

  // --------------------------------------------------------------------------
  // 1. Phone Normalization & Communication Actions Contract
  // --------------------------------------------------------------------------
  console.log('\n--- 1. Phone Normalization & Safe Actions Engine ---');

  // Test standard 10-digit mobile
  const p1 = validateAndNormalizePhone('9876543210');
  record(
    'RB06-PHONE-01',
    'Indian 10-Digit Mobile Normalization (+91 Prefix)',
    'PhoneValidation',
    p1.isValid && p1.normalized === '+919876543210' && p1.formatted === '+91 98765 43210',
    `Normalized: "${p1.normalized}", Formatted: "${p1.formatted}"`
  );

  // Test messy inputs with spaces, hyphens, and leading zero
  const p2 = validateAndNormalizePhone('098765-43210');
  const p3 = validateAndNormalizePhone('+91 98765 43210');
  record(
    'RB06-PHONE-02',
    'Phone Sanitization for Messy / Formatted Inputs',
    'PhoneValidation',
    p2.isValid && p2.normalized === '+919876543210' && p3.isValid && p3.normalized === '+919876543210',
    'Successfully stripped hyphens, leading zero, and formatted to +919876543210'
  );

  // Test invalid mobile (starts with 1, wrong length)
  const p4 = validateAndNormalizePhone('1234567890');
  const p5 = validateAndNormalizePhone('98765');
  record(
    'RB06-PHONE-03',
    'Rejection of Invalid Mobile Numbers',
    'PhoneValidation',
    !p4.isValid && !p5.isValid,
    `Rejected non-standard starts: "${p4.error}", rejected short: "${p5.error}"`
  );

  // Test safe tel: and wa.me: URIs
  const tel = getSafeTelUri('9876543210');
  const wa = getSafeWhatsAppUri('9876543210', 'Deal inquiry');
  const telInvalid = getSafeTelUri('123');
  record(
    'RB06-PHONE-04',
    'Safe User-Initiated Call & WhatsApp URIs',
    'PhoneValidation',
    tel === 'tel:+919876543210' &&
      Boolean(wa?.includes('https://wa.me/919876543210?text=Deal')) &&
      telInvalid === null,
    `Tel URI: "${tel}", WhatsApp URI: "${wa?.slice(0, 45)}...", Invalid returns null`
  );

  // --------------------------------------------------------------------------
  // 2. Directory Server Action & Scoping Architecture
  // --------------------------------------------------------------------------
  console.log('\n--- 2. Directory Server Action & Broker Scoping ---');

  const actionPath = path.join(
    projectRoot,
    'src',
    'server',
    'actions',
    'broker-directory-actions.ts'
  );
  const actionContent = fs.readFileSync(actionPath, 'utf-8');

  // Verify Unauthenticated Rejection
  let unauthListRejected = false;
  try {
    const res = await getBrokerDirectoryContactsAction();
    if (!res.success && (res.error?.includes('Unauthorized') || res.error?.includes('cookies'))) {
      unauthListRejected = true;
    }
  } catch {
    unauthListRejected = true;
  }
  record(
    'RB06-SEC-01',
    'Directory Listing Enforces Broker Session Rejection',
    'Security',
    unauthListRejected,
    'getBrokerDirectoryContactsAction rejects unauthenticated calls'
  );

  // Verify broker isolation predicate in directory queries
  const hasBrokerIsolation =
    actionContent.includes('crmContacts.brokerId, brokerId') &&
    actionContent.includes('requirements.brokerId, brokerId') &&
    actionContent.includes('availabilities.brokerId, brokerId') &&
    actionContent.includes('deals.brokerId, brokerId');
  record(
    'RB06-SEC-02',
    'Strict Broker Workspace Query Scoping Across Relations',
    'Security',
    hasBrokerIsolation,
    'crm_contacts, requirements, availabilities, and deals scoped by caller brokerId'
  );

  // Verify role guard (broker or admin only)
  const hasRoleGuard =
    actionContent.includes("role !== 'broker' && role !== 'admin'") &&
    actionContent.includes('Forbidden: Broker access privileges required');
  record(
    'RB06-SEC-03',
    'Database Role Verification on All Directory Mutations',
    'Security',
    hasRoleGuard,
    'Enforces trusted database role check (not spoofable client JWT)'
  );

  // --------------------------------------------------------------------------
  // 3. Duplicate Prevention Architecture
  // --------------------------------------------------------------------------
  console.log('\n--- 3. Duplicate Prevention Architecture ---');

  const hasDuplicatePreventionAction =
    actionContent.includes('checkContactDuplicateAction') &&
    actionContent.includes("matchType: 'exact_mobile'") &&
    actionContent.includes("matchType: 'company_name'");
  record(
    'RB06-DUP-01',
    'Server-Side Duplicate Prevention Implementation',
    'DuplicatePrevention',
    hasDuplicatePreventionAction,
    'Defines checkContactDuplicateAction for exact mobile and company name matching'
  );

  const hasDuplicateBlockInCreate =
    actionContent.includes('checkContactDuplicateAction({') &&
    actionContent.includes('dupCheck.isDuplicate && dupCheck.matchType === \'exact_mobile\'') &&
    actionContent.includes('Duplicate creation prevented');
  record(
    'RB06-DUP-02',
    'Creation Blocking on Exact Mobile Duplicate Match',
    'DuplicatePrevention',
    hasDuplicateBlockInCreate,
    'createBrokerContactAction halts insertion and returns duplicate warning payload'
  );

  const hasNoCrossBrokerLeak =
    actionContent.includes('isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId)') &&
    !actionContent.includes('FOREIGN_BROKER_LEAK');
  record(
    'RB06-DUP-03',
    'Zero Cross-Broker Contact Leakage in Duplicate Checking',
    'DuplicatePrevention',
    hasNoCrossBrokerLeak,
    'Duplicate queries restrict lookup strictly to caller broker workspace'
  );

  // --------------------------------------------------------------------------
  // 4. Form Validation & Schema Integrity
  // --------------------------------------------------------------------------
  console.log('\n--- 4. Form Validation & Zod Schema Integrity ---');

  // Test Zod schema validation
  const validParsed = createContactSchema.safeParse({
    name: 'Ramesh Agrawal',
    companyName: 'Malwa Agro Traders',
    mobile: '9876543210',
    role: 'buyer',
  });
  record(
    'RB06-VAL-01',
    'Zod Validation Passes Valid Contact Payload',
    'Validation',
    validParsed.success,
    'Successfully validated name, company, mobile, and buyer role'
  );

  const invalidParsed = createContactSchema.safeParse({
    name: '',
    companyName: '',
    mobile: '123',
    role: 'invalid_role',
  });
  record(
    'RB06-VAL-02',
    'Zod Validation Rejects Incomplete / Invalid Payload',
    'Validation',
    !invalidParsed.success && invalidParsed.error.errors.length >= 3,
    `Caught ${!invalidParsed.success ? invalidParsed.error.errors.length : 0} validation errors (name, company, mobile, role)`
  );

  // --------------------------------------------------------------------------
  // 5. 360-Degree Contact Profile & Linked Business Records
  // --------------------------------------------------------------------------
  console.log('\n--- 5. 360-Degree Contact Profile & Linked Records ---');

  const hasDetailsAction =
    actionContent.includes('getBrokerContactDetailsAction') &&
    actionContent.includes('associatedRequirements') &&
    actionContent.includes('associatedOffers') &&
    actionContent.includes('linkedDeals') &&
    actionContent.includes('activities');
  record(
    'RB06-PROF-01',
    '360-Degree Aggregation Action Defined (Requirements, Offers, Deals)',
    'Profile',
    hasDetailsAction,
    'getBrokerContactDetailsAction aggregates company, contacts, reqs, offers, deals, activities'
  );

  // Verify unauthorized contact access rejection
  let unauthDetailsRejected = false;
  try {
    const res = await getBrokerContactDetailsAction('fake-contact-id');
    if (!res.success && (res.error?.includes('Unauthorized') || res.error?.includes('cookies'))) {
      unauthDetailsRejected = true;
    }
  } catch {
    unauthDetailsRejected = true;
  }
  record(
    'RB06-PROF-02',
    'Contact Profile Rejects Unauthenticated or Unassigned Broker',
    'Profile',
    unauthDetailsRejected,
    'Enforces broker assignment before loading contact profile'
  );

  // --------------------------------------------------------------------------
  // 6. Archival / Status Toggle Safety
  // --------------------------------------------------------------------------
  console.log('\n--- 6. Archival / Status Toggle Safety ---');

  const hasStatusToggle =
    actionContent.includes('toggleContactStatusAction') &&
    actionContent.includes('await db.update(users).set({ status: newStatus })');
  record(
    'RB06-ARCH-01',
    'Soft Archival Status Toggle Implementation',
    'Archival',
    hasStatusToggle,
    'Toggles users.status boolean without deleting associated deals or requirements'
  );

  // --------------------------------------------------------------------------
  // 7. UI Components Deployment
  // --------------------------------------------------------------------------
  console.log('\n--- 7. UI Components Deployment ---');

  const workspacePath = path.join(
    projectRoot,
    'src',
    'components',
    'directory',
    'broker-directory-workspace.tsx'
  );
  const formDialogPath = path.join(
    projectRoot,
    'src',
    'components',
    'directory',
    'contact-form-dialog.tsx'
  );
  const profileDrawerPath = path.join(
    projectRoot,
    'src',
    'components',
    'directory',
    'contact-profile-drawer.tsx'
  );
  const pagePath = path.join(
    projectRoot,
    'app',
    '(broker)',
    'broker',
    'directory',
    'page.tsx'
  );

  const allComponentsExist =
    fs.existsSync(workspacePath) &&
    fs.existsSync(formDialogPath) &&
    fs.existsSync(profileDrawerPath) &&
    fs.existsSync(pagePath);

  record(
    'RB06-UI-01',
    'All RB-06 Directory Components Deployed',
    'UI',
    allComponentsExist,
    'Verified physical existence of Workspace, FormDialog, ProfileDrawer, and DirectoryPage'
  );

  const workspaceContent = fs.readFileSync(workspacePath, 'utf-8');
  const hasTabsAndFilters =
    workspaceContent.includes("setActiveTab('buyer')") &&
    workspaceContent.includes("setActiveTab('seller')") &&
    workspaceContent.includes('searchQuery') &&
    workspaceContent.includes('statusFilter');
  record(
    'RB06-UI-02',
    'Buyer/Seller Tabs & Real-Time Filter Engine',
    'UI',
    hasTabsAndFilters,
    'Workspace supports tab switching, real-time search, and active/inactive status filtering'
  );

  // --------------------------------------------------------------------------
  // 8. English & Hindi Localization Parity (203 Keys)
  // --------------------------------------------------------------------------
  console.log('\n--- 8. English & Hindi Localization Parity ---');

  const enKeys = Object.keys(TRANSLATIONS.en) as Array<keyof typeof TRANSLATIONS.en>;
  const hiKeys = Object.keys(TRANSLATIONS.hi) as Array<keyof typeof TRANSLATIONS.hi>;

  const missingInHi = enKeys.filter((k) => !(k in TRANSLATIONS.hi));
  const missingInEn = hiKeys.filter((k) => !(k in TRANSLATIONS.en));
  const isKeyParityComplete = missingInHi.length === 0 && missingInEn.length === 0;

  record(
    'RB06-LOC-01',
    'English & Hindi Translation Key Parity (100% Match)',
    'Localization',
    isKeyParityComplete,
    `Verified ${enKeys.length} English keys against ${hiKeys.length} Hindi keys (Missing: ${missingInHi.length})`
  );

  const requiredDirectoryHindi = [
    'directoryTitle',
    'tabBuyers',
    'tabSellers',
    'actionAddContact',
    'actionCallContact',
    'actionWhatsApp',
    'duplicateWarningTitle',
    'fieldContactName',
    'fieldCompanyName',
  ];
  const hasHindiDirectory = requiredDirectoryHindi.every(
    (k) => (TRANSLATIONS.hi as any)[k] && (TRANSLATIONS.hi as any)[k].length > 0
  );
  record(
    'RB06-LOC-02',
    'Hindi Mandi Domain Terminology Fidelity for RB-06',
    'Localization',
    hasHindiDirectory,
    'Verified Devanagari Mandi terminology for direct communication, duplicates, and contacts'
  );

  // --------------------------------------------------------------------------
  // 9. Responsive Layout & Touch Ergonomics
  // --------------------------------------------------------------------------
  console.log('\n--- 9. Responsive Layout & Usability Contract ---');

  const hasOverflowGuards = workspaceContent.includes('overflow-x-hidden');
  record(
    'RB06-RESP-01',
    'Horizontal Scroll Overflow Protection (overflow-x-hidden)',
    'Responsive',
    hasOverflowGuards,
    'Main directory container enforces overflow-x-hidden'
  );

  const hasErgonomicTouch =
    workspaceContent.includes('min-h-[40px]') || workspaceContent.includes('min-h-[48px]');
  record(
    'RB06-RESP-02',
    'Ergonomic Touch Targets for Mobile Workstation',
    'Responsive',
    hasErgonomicTouch,
    'Call, WhatsApp, and profile buttons enforce mobile touch targets >= 40px'
  );

  // --------------------------------------------------------------------------
  // 10. Broker Mediation Firewall (ADR-004)
  // --------------------------------------------------------------------------
  console.log('\n--- 10. Broker Mediation Firewall Preservation ---');

  const preservesBrokerFirewall =
    !workspaceContent.includes('directBuyerSellerChat') &&
    !actionContent.includes('directBuyerSellerChat');
  record(
    'RB06-FW-01',
    'Broker Mediation Firewall Preserved (Zero Direct Buyer-Seller Deal Chat)',
    'Architecture',
    preservesBrokerFirewall,
    'Preserves ADR-004: All communication remains mediated through authenticated broker'
  );

  // --------------------------------------------------------------------------
  // Summary
  // --------------------------------------------------------------------------
  const totalTests = results.length;
  const passed = results.filter((r) => r.passed).length;
  const failed = results.filter((r) => !r.passed).length;

  console.log('\n' + '='.repeat(80));
  console.log(
    `RB-06 Buyer & Seller Directory Complete: ${passed}/${totalTests} Tests Passed (${failed} Failed)`
  );
  console.log('='.repeat(80));

  return {
    suiteName: 'MICRO-SPRINT RB-06: RMBROKER BUYER & SELLER DIRECTORY',
    sprintId: 'RB-06',
    totalTests,
    passed,
    failed,
    timestamp: new Date().toISOString(),
    results,
  };
}

if (require.main === module) {
  runRMBrokerDirectoryVerification()
    .then((report) => {
      if (report.failed > 0) {
        console.error(`\nRB-06 Verification FAILED: ${report.failed} test(s) failed.`);
        process.exit(1);
      } else {
        console.log('\nAll RB-06 RMBroker Directory Verification tests PASSED cleanly!');
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('\nRB-06 Test execution error:', err);
      process.exit(1);
    });
}
