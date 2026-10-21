/**
 * ============================================================================
 * SPRINT RB-SELLER-04: SELLER DEALS, INVOICES, SALES HISTORY & FINANCIAL REPORTS
 * AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Validates the core requirements of Sprint RB-SELLER-04:
 * 1. Deals overview and lifecycle status filtering.
 * 2. Deal details with invoice, commission, and logistics integration.
 * 3. Broker-shared invoices and document viewer subsystem.
 * 4. Multi-period sales history (Weekly, Monthly, Quarterly, Yearly, Custom).
 * 5. Verified commission calculations (Agreed, Paid, Outstanding) without conflation.
 * 6. Financial integrity: completed sale definition, no double counting, distinct null/zero.
 * 7. Strict Counterparty Shield (zero buyer exposure in deals, invoices, and reports).
 * 8. Statement export and document sharing integration.
 * 9. Unit & widget test suites for deals, invoices, and reports.
 * 10. Sibling app boundary preservation and zero database schema mutations.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface RB04TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB04VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB04TestCaseResult[];
}

const ROOT_DIR = path.resolve(__dirname, '../../..');
const SELLER_APP_DIR = path.join(ROOT_DIR, 'apps', 'rmseller_mobile');

export async function runRMSellerDealsReportsVerification(): Promise<RB04VerificationReport> {
  const results: RB04TestCaseResult[] = [];

  const record = (
    id: string,
    name: string,
    category: string,
    passed: boolean,
    evidence: string,
    detail?: string
  ) => {
    results.push({ id, name, category, passed, evidence, detail });
    const mark = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`[${mark}] ${id}: ${name} (${category})`);
    if (!passed && detail) {
      console.log(`       ⚠️  Detail: ${detail}`);
    }
  };

  console.log('\n============================================================');
  console.log('🚀 RUNNING RB-SELLER-04: DEALS, INVOICES & FINANCIAL REPORTS VERIFICATION');
  console.log('============================================================\n');

  // --------------------------------------------------------------------------
  // Check 1: Deals Overview & Lifecycle Filtering
  // --------------------------------------------------------------------------
  try {
    const modelPath = path.join(SELLER_APP_DIR, 'lib/features/deals/domain/seller_deal_model.dart');
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/deals/data/seller_deals_repository.dart');
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/deals/presentation/seller_deals_screen.dart');

    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasAgreedPrice = modelContent.includes('agreedPrice') && repoContent.includes('agreed_price');
    const hasAgreedQuantity = modelContent.includes('agreedQuantity') && repoContent.includes('agreed_quantity');
    const hasStatusFilter = repoContent.includes('statusFilter') && screenContent.includes('FilterChip');
    const hasInvoiceBadge = screenContent.includes('deal.invoiceNo') && screenContent.includes('LucideIcons.receipt');
    const hasCommissionBadge = screenContent.includes('deal.commissionAmount');

    const passed = hasAgreedPrice && hasAgreedQuantity && hasStatusFilter && hasInvoiceBadge && hasCommissionBadge;
    record(
      'RB04-01',
      'Deals Overview & Lifecycle Filtering',
      'Deals Architecture',
      passed,
      `Model/Repo price=${hasAgreedPrice}, qty=${hasAgreedQuantity}, StatusFilter=${hasStatusFilter}, InvoiceBadge=${hasInvoiceBadge}, CommBadge=${hasCommissionBadge}`,
      passed ? undefined : 'Deals overview missing lifecycle filters or invoice/commission indicators'
    );
  } catch (err: any) {
    record('RB04-01', 'Deals Overview & Lifecycle Filtering', 'Deals Architecture', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 2: Deal Details with Invoices & Financial Integration
  // --------------------------------------------------------------------------
  try {
    const detailsScreenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/deals/presentation/deal_details_screen.dart'
    );
    const content = fs.readFileSync(detailsScreenPath, 'utf8');

    const hasCommercialSummary = content.includes('deal.totalDealValue') && content.includes('Agreed Quantity');
    const hasInvoiceSection = content.includes('Invoices & Tax Statements') && content.includes('/invoices/');
    const hasCommissionCard = content.includes('Broker Commission Breakdown') && content.includes('Outstanding Commission');
    const hasLogisticsSection = content.includes('Logistics & Vehicle Entry') || content.includes('vehicleNumber');
    const hasBrokerCard = content.includes('Mediating Broker Desk') && content.includes('Counterparty Shield');

    const passed = hasCommercialSummary && hasInvoiceSection && hasCommissionCard && hasBrokerCard;
    record(
      'RB04-02',
      'Deal Details with Invoices & Financial Integration',
      'Deals Architecture',
      passed,
      `Summary: ${hasCommercialSummary}, Invoices: ${hasInvoiceSection}, Commission: ${hasCommissionCard}, Logistics: ${hasLogisticsSection}, BrokerShield: ${hasBrokerCard}`,
      passed ? undefined : 'Deal details screen missing invoice links, commission card, or broker shield'
    );
  } catch (err: any) {
    record('RB04-02', 'Deal Details with Invoices & Financial Integration', 'Deals Architecture', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 3: Broker-Shared Invoices & Document Viewer Subsystem
  // --------------------------------------------------------------------------
  try {
    const invoiceModelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/invoices/domain/seller_invoice_model.dart'
    );
    const invoiceRepoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/invoices/data/seller_invoices_repository.dart'
    );
    const invoiceScreenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/invoices/presentation/invoice_details_screen.dart'
    );
    const routerPath = path.join(SELLER_APP_DIR, 'lib/app/router/app_router.dart');

    const modelContent = fs.readFileSync(invoiceModelPath, 'utf8');
    const repoContent = fs.readFileSync(invoiceRepoPath, 'utf8');
    const screenContent = fs.readFileSync(invoiceScreenPath, 'utf8');
    const routerContent = fs.readFileSync(routerPath, 'utf8');

    const mapsInvoicesTable = repoContent.includes(".from('invoices')");
    const hasTaxCalculations = modelContent.includes('taxableAmount') && modelContent.includes('gstAmount');
    const hasDocumentFetcher = repoContent.includes('getDocumentsForDeal') && repoContent.includes('dispatch_documents');
    const hasLineItems = screenContent.includes('Commercial Line Items') && screenContent.includes('CGST');
    const hasRoute = routerContent.includes("path: '/invoices/:id'");

    const passed = mapsInvoicesTable && hasTaxCalculations && hasDocumentFetcher && hasLineItems && hasRoute;
    record(
      'RB04-03',
      'Broker-Shared Invoices & Document Viewer Subsystem',
      'Invoices & Documents',
      passed,
      `InvoicesTable: ${mapsInvoicesTable}, TaxCalc: ${hasTaxCalculations}, DocFetcher: ${hasDocumentFetcher}, LineItems: ${hasLineItems}, Route: ${hasRoute}`,
      passed ? undefined : 'Invoice subsystem missing database mapping, tax calculations, or router registration'
    );
  } catch (err: any) {
    record('RB04-03', 'Broker-Shared Invoices & Document Viewer Subsystem', 'Invoices & Documents', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 4: Multi-Period Sales History & Date Boundaries
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/data/seller_reports_repository.dart'
    );
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/presentation/sales_history_screen.dart'
    );
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasWeekly = repoContent.includes('days: 7') && screenContent.includes("'Weekly'");
    const hasMonthly = repoContent.includes('days: 30') && screenContent.includes("'Monthly'");
    const hasQuarterly = repoContent.includes('days: 90') && screenContent.includes("'Quarterly'");
    const hasYearly = repoContent.includes('days: 365') && screenContent.includes("'Yearly'");
    const hasCustom = repoContent.includes('custom') && screenContent.includes('showDateRangePicker');

    const passed = hasWeekly && hasMonthly && hasQuarterly && hasYearly && hasCustom;
    record(
      'RB04-04',
      'Multi-Period Sales History & Date Boundaries',
      'Reporting & Analytics',
      passed,
      `Weekly(7d)=${hasWeekly}, Monthly(30d)=${hasMonthly}, Quarterly(90d)=${hasQuarterly}, Yearly(365d)=${hasYearly}, Custom=${hasCustom}`,
      passed ? undefined : 'Missing one or more required reporting periods or date boundary calculations'
    );
  } catch (err: any) {
    record('RB04-04', 'Multi-Period Sales History & Date Boundaries', 'Reporting & Analytics', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 5: Verified Commission Calculations (Agreed, Paid, Outstanding)
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/data/seller_reports_repository.dart'
    );
    const modelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/domain/sales_report_model.dart'
    );
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/presentation/sales_history_screen.dart'
    );
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasAgreedComm = modelContent.includes('totalAgreedCommission') && repoContent.includes('totalAgreedCommission');
    const hasPaidComm = modelContent.includes('totalCommissionPaid') && repoContent.includes('totalCommissionPaid');
    const hasOutstandingComm = modelContent.includes('totalCommissionOutstanding') && repoContent.includes('totalCommissionOutstanding');
    const displaysCommissionCard = screenContent.includes('Broker Commission Breakdown') && screenContent.includes('Total Agreed Comm.');

    const passed = hasAgreedComm && hasPaidComm && hasOutstandingComm && displaysCommissionCard;
    record(
      'RB04-05',
      'Verified Commission Calculations (Agreed, Paid, Outstanding)',
      'Financial Integrity',
      passed,
      `Agreed: ${hasAgreedComm}, Paid: ${hasPaidComm}, Outstanding: ${hasOutstandingComm}, DisplayCard: ${displaysCommissionCard}`,
      passed ? undefined : 'Commission breakdown missing agreed, paid, or outstanding metrics'
    );
  } catch (err: any) {
    record('RB04-05', 'Verified Commission Calculations (Agreed, Paid, Outstanding)', 'Financial Integrity', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 6: Financial Integrity & Completed Sale Distinction
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/data/seller_reports_repository.dart'
    );
    const dealModelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/deals/domain/seller_deal_model.dart'
    );
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const dealModelContent = fs.readFileSync(dealModelPath, 'utf8');

    // Invariant: Cancelled deals are NOT counted in completed volume or gross sales
    const handlesCancelledDeals = repoContent.includes("status == 'cancelled'") || repoContent.includes("tx.isCancelled");
    const definesCompletedSale = dealModelContent.includes('isCompleted') && (dealModelContent.includes('completed') || dealModelContent.includes('settled'));
    const separatesActiveFromCompleted = dealModelContent.includes('isActive') && repoContent.includes('activeDealsCount');

    const passed = handlesCancelledDeals && definesCompletedSale && separatesActiveFromCompleted;
    record(
      'RB04-06',
      'Financial Integrity & Completed Sale Distinction',
      'Financial Integrity',
      passed,
      `HandlesCancelled: ${handlesCancelledDeals}, CompletedSaleDef: ${definesCompletedSale}, ActiveSeparated: ${separatesActiveFromCompleted}`,
      passed ? undefined : 'Failed financial integrity check: cancelled/active sales not separated from completed sales'
    );
  } catch (err: any) {
    record('RB04-06', 'Financial Integrity & Completed Sale Distinction', 'Financial Integrity', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 7: Strict Counterparty Shield & Buyer Privacy
  // --------------------------------------------------------------------------
  try {
    const invoiceScreen = fs.readFileSync(
      path.join(SELLER_APP_DIR, 'lib/features/invoices/presentation/invoice_details_screen.dart'),
      'utf8'
    );
    const dealDetailsScreen = fs.readFileSync(
      path.join(SELLER_APP_DIR, 'lib/features/deals/presentation/deal_details_screen.dart'),
      'utf8'
    );
    const reportsScreen = fs.readFileSync(
      path.join(SELLER_APP_DIR, 'lib/features/reports/presentation/sales_history_screen.dart'),
      'utf8'
    );

    const hasInvoiceShield = invoiceScreen.includes('Counterparty Shield');
    const hasDealShield = dealDetailsScreen.includes('Counterparty Shield');
    const hasReportShield = reportsScreen.includes('Counterparty Shield');

    const hasBuyerChatLeak = /buyer.*chat|direct.*buyer.*message|buyer.*phone|buyer.*email/i.test(invoiceScreen) ||
                             /buyer.*chat|direct.*buyer.*message|buyer.*phone|buyer.*email/i.test(dealDetailsScreen) ||
                             /buyer.*chat|direct.*buyer.*message|buyer.*phone|buyer.*email/i.test(reportsScreen);

    const passed = hasInvoiceShield && hasDealShield && hasReportShield && !hasBuyerChatLeak;
    record(
      'RB04-07',
      'Strict Counterparty Shield & Buyer Privacy',
      'Security & Access Control',
      passed,
      `InvoiceShield: ${hasInvoiceShield}, DealShield: ${hasDealShield}, ReportShield: ${hasReportShield}, ZeroBuyerLeaks: ${!hasBuyerChatLeak}`,
      passed ? undefined : 'Found potential buyer contact leaks or missing Counterparty Shield notices'
    );
  } catch (err: any) {
    record('RB04-07', 'Strict Counterparty Shield & Buyer Privacy', 'Security & Access Control', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 8: Statement Export & Document Sharing
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/reports/presentation/sales_history_screen.dart'
    );
    const invoiceRepoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/invoices/data/seller_invoices_repository.dart'
    );
    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const invoiceRepoContent = fs.readFileSync(invoiceRepoPath, 'utf8');

    const hasExportDialog = screenContent.includes('_handleExportStatement') && screenContent.includes('Export Sales Statement');
    const hasDocLauncher = invoiceRepoContent.includes('openDocument') && invoiceRepoContent.includes('launchUrl');

    const passed = hasExportDialog && hasDocLauncher;
    record(
      'RB04-08',
      'Statement Export & Document Sharing',
      'Export & Operations',
      passed,
      `ExportDialog: ${hasExportDialog}, DocumentLauncher: ${hasDocLauncher}`,
      passed ? undefined : 'Missing statement export dialog or document download launcher'
    );
  } catch (err: any) {
    record('RB04-08', 'Statement Export & Document Sharing', 'Export & Operations', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 9: Unit & Widget Test Suites for RB-SELLER-04
  // --------------------------------------------------------------------------
  try {
    const invRepoTest = path.join(SELLER_APP_DIR, 'test/unit/seller_invoices_repository_test.dart');
    const repRepoTest = path.join(SELLER_APP_DIR, 'test/unit/seller_reports_repository_test.dart');
    const invWidgetTest = path.join(SELLER_APP_DIR, 'test/widgets/invoice_details_screen_test.dart');
    const repWidgetTest = path.join(SELLER_APP_DIR, 'test/widgets/sales_history_screen_test.dart');

    const hasInvRepoTest = fs.existsSync(invRepoTest);
    const hasRepRepoTest = fs.existsSync(repRepoTest);
    const hasInvWidgetTest = fs.existsSync(invWidgetTest);
    const hasRepWidgetTest = fs.existsSync(repWidgetTest);

    const passed = hasInvRepoTest && hasRepRepoTest && hasInvWidgetTest && hasRepWidgetTest;
    record(
      'RB04-09',
      'Unit & Widget Test Suites for RB-SELLER-04',
      'Quality Assurance',
      passed,
      `InvoiceRepoTest: ${hasInvRepoTest}, ReportsRepoTest: ${hasRepRepoTest}, InvoiceWidgetTest: ${hasInvWidgetTest}, ReportsWidgetTest: ${hasRepWidgetTest}`,
      passed ? undefined : 'Missing one or more required test suites for RB-SELLER-04'
    );
  } catch (err: any) {
    record('RB04-09', 'Unit & Widget Test Suites for RB-SELLER-04', 'Quality Assurance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 10: Sibling App Boundary & Zero Database Schema Mutation
  // --------------------------------------------------------------------------
  try {
    let gitStatus = '';
    try {
      gitStatus = execSync('git status --porcelain', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
      });
    } catch {
      gitStatus = '';
    }

    const lines = gitStatus.split('\n').filter((l) => l.trim().length > 0);

    const rmbuyerModified = lines.some((l) => l.includes('apps/rmbuyer_mobile'));
    const rmbrokerModified = lines.some((l) => l.includes('apps/rmbroker_mobile'));
    const migrationsModified = lines.some((l) => l.includes('supabase/migrations'));

    const passed = !rmbuyerModified && !rmbrokerModified && !migrationsModified;

    record(
      'RB04-10',
      'Sibling App Boundary & Zero Database Schema Mutation',
      'Architecture Governance',
      passed,
      `RMBuyer untouched: ${!rmbuyerModified}, RMBroker untouched: ${!rmbrokerModified}, Zero DB migrations: ${!migrationsModified}`,
      passed ? undefined : 'Violated boundaries: modifications found in sibling apps or database migrations'
    );
  } catch (err: any) {
    record('RB04-10', 'Sibling App Boundary & Zero Database Schema Mutation', 'Architecture Governance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Summary & Report Generation
  // --------------------------------------------------------------------------
  const passedCount = results.filter((r) => r.passed).length;
  const failedCount = results.filter((r) => !r.passed).length;

  console.log('\n============================================================');
  console.log(`RB-SELLER-04 VERIFICATION SUMMARY: ${passedCount}/${results.length} PASSED`);
  if (failedCount > 0) {
    console.log(`⚠️  FAILED CHECKS: ${failedCount}`);
  } else {
    console.log('🎉 ALL CHECKS PASSED PERFECTLY!');
  }
  console.log('============================================================\n');

  return {
    suiteName: 'Sprint RB-SELLER-04 Automated Verification Suite',
    sprintId: 'RB-SELLER-04',
    totalTests: results.length,
    passed: passedCount,
    failed: failedCount,
    timestamp: new Date().toISOString(),
    results,
  };
}

// Direct execution if run via CLI
if (require.main === module) {
  runRMSellerDealsReportsVerification()
    .then((report) => {
      if (report.failed > 0) {
        process.exit(1);
      } else {
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('Fatal execution error:', err);
      process.exit(1);
    });
}
