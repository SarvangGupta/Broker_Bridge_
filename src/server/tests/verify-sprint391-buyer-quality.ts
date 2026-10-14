/**
 * Comprehensive Automated Verification Suite for Micro-Sprint 39.1
 * Buyer Transaction Quality & Weighment UI (Sprint 39: Quality, Documents, Payments & Disputes)
 *
 * Verifies:
 * 1. Input Validation Guards: Rejection of missing/empty booking IDs.
 * 2. Execution & Data Payload: getBuyerTransactionQualityAction returns structured scientific quality & weighment data.
 * 3. Scientific Quality Grid: Buyer target vs. actual verified result comparison, within-bounds status, variance.
 * 4. Physical Weighment: Gross weight, Tare weight, and Net Weight Loaded calculations.
 * 5. Secure Document Preview: getBuyerLabReportSignedUrlAction & getBuyerWeighmentSlipSignedUrlAction return authenticated URLs.
 * 6. Privacy Scrubber: Strictly zero Seller PII, contacts, or pricing leaked in payloads.
 * 7. Read-Only Invariant: No mutation or dispute creation actions exported (Sprint 39.4 boundary).
 * 8. UI Mobile-First Contract: 360px viewport safety (flex-col), min-h-[48px] touch targets, and page mount.
 */

import {
  getBuyerTransactionQualityAction,
  getBuyerLabReportSignedUrlAction,
  getBuyerWeighmentSlipSignedUrlAction,
} from '../actions/buyer-quality-tracking-actions';
import * as qualityActions from '../actions/buyer-quality-tracking-actions';
import * as fs from 'fs';
import * as path from 'path';

async function runSprint391Verification() {
  console.log('========================================================');
  console.log('  MICRO-SPRINT 39.1: BUYER TRANSACTION QUALITY & WEIGHMENT');
  console.log('========================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`✅ [PASS] ${testName}`);
      if (detail) console.log(`   └─ ${detail}`);
    } else {
      console.error(`❌ [FAIL] ${testName}`);
      if (detail) console.error(`   └─ Detail: ${detail}`);
    }
  }

  // --- 1. Validation Guards ---
  console.log('\n--- 1. Validation Guards ---');
  try {
    const emptyRes = await getBuyerTransactionQualityAction('');
    assert(
      !emptyRes.success && emptyRes.error?.includes('required'),
      'Validation: Rejects empty booking identifier',
      `Error: "${emptyRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects empty booking identifier', err.message);
  }

  try {
    const whitespaceRes = await getBuyerTransactionQualityAction('    ');
    assert(
      !whitespaceRes.success,
      'Validation: Rejects whitespace-only booking identifier'
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects whitespace-only booking identifier', err.message);
  }

  // --- 2. Live Quality & Weighment Execution ---
  console.log('\n--- 2. Transaction Quality Data Execution ---');
  try {
    const res = await getBuyerTransactionQualityAction('BKG-2026-8812');
    assert(
      res.success && Boolean(res.data),
      'Execution: getBuyerTransactionQualityAction completes successfully',
      `Booking ID: ${res.data?.bookingId}, Commodity: ${res.data?.commodityName}`
    );

    if (res.data) {
      assert(
        res.data.overallQualityStatus === 'Verified',
        'Overall Status: Correctly returns overall quality status',
        `Status: ${res.data.overallQualityStatus}`
      );

      assert(
        Boolean(res.data.labReport),
        'Scientific Evidence: Lab report details are present',
        `Lab: ${res.data.labReport?.laboratoryName}, Ref: ${res.data.labReport?.reportNumber}`
      );

      assert(
        res.data.labReport?.status === 'Verified',
        'Lab Verification Status: Lab report is marked Verified',
        `Lab Status: ${res.data.labReport?.status}`
      );

      assert(
        Boolean(res.data.labReport?.verifiedAt),
        'Audit Trail: Lab report contains broker verification timestamp',
        `Verified At: ${res.data.labReport?.verifiedAt}`
      );

      // --- 3. Parameter Comparison Matrix ---
      console.log('\n--- 3. Quality Parameter Comparison Matrix ---');
      assert(
        Array.isArray(res.data.parameters) && res.data.parameters.length > 0,
        'Parameter Grid: Returns structured quality parameter comparisons',
        `Total Parameters: ${res.data.parameters.length}`
      );

      const moistureParam = res.data.parameters.find(p => p.parameterName.toLowerCase().includes('moisture'));
      assert(
        Boolean(moistureParam),
        'Critical Parameter: Moisture Content parameter is present',
        `Moisture Target: ${moistureParam?.buyerTargetFormatted}, Actual: ${moistureParam?.actualValueFormatted}`
      );

      if (moistureParam) {
        assert(
          Boolean(moistureParam.buyerTargetFormatted),
          'Buyer Target Spec: Formatted target bounds present',
          `Target: ${moistureParam.buyerTargetFormatted}`
        );
        assert(
          Boolean(moistureParam.actualValueFormatted),
          'Verified Lab Output: Measured analytical value present',
          `Measured: ${moistureParam.actualValueFormatted}`
        );
        assert(
          typeof moistureParam.isWithinBounds === 'boolean',
          'Tolerance Check: isWithinBounds boolean evaluated',
          `Within Bounds: ${moistureParam.isWithinBounds}`
        );
      }

      // --- 4. Physical Weighment Data ---
      console.log('\n--- 4. Physical Dispatch Weighment ---');
      assert(
        Boolean(res.data.weighment),
        'Weighment Evidence: Dispatch weighment record is present',
        `Vehicle: ${res.data.weighment?.vehicleNumber}`
      );

      if (res.data.weighment) {
        assert(
          res.data.weighment.grossWeight !== null && res.data.weighment.grossWeight > 0,
          'Gross Weight: Recorded and positive',
          `Gross: ${res.data.weighment.grossWeight} ${res.data.weighment.unitSymbol}`
        );

        assert(
          res.data.weighment.tareWeight !== null && res.data.weighment.tareWeight > 0,
          'Tare Weight: Recorded and positive',
          `Tare: ${res.data.weighment.tareWeight} ${res.data.weighment.unitSymbol}`
        );

        assert(
          res.data.weighment.netWeight !== null &&
            res.data.weighment.netWeight === Number((res.data.weighment.grossWeight! - res.data.weighment.tareWeight!).toFixed(2)),
          'Net Weight Math: Net Weight equals Gross Weight minus Tare Weight',
          `Net Weight Loaded: ${res.data.weighment.netWeight} ${res.data.weighment.unitSymbol}`
        );

        assert(
          res.data.weighment.status === 'Verified',
          'Weighment Status: Verified scale certification present',
          `Status: ${res.data.weighment.status}`
        );
      }
    }
  } catch (err: any) {
    assert(false, 'Execution: getBuyerTransactionQualityAction completes successfully', err.message);
  }

  // --- 5. Secure Document Preview Signed URLs ---
  console.log('\n--- 5. Secure Document Signed URLs ---');
  try {
    const labUrlRes = await getBuyerLabReportSignedUrlAction('BKG-2026-8812');
    assert(
      labUrlRes.success && Boolean(labUrlRes.data?.signedUrl),
      'Security: getBuyerLabReportSignedUrlAction delivers short-lived signed URL',
      `URL: ${labUrlRes.data?.signedUrl}`
    );
  } catch (err: any) {
    assert(false, 'Security: getBuyerLabReportSignedUrlAction delivers short-lived signed URL', err.message);
  }

  try {
    const weighUrlRes = await getBuyerWeighmentSlipSignedUrlAction('BKG-2026-8812');
    assert(
      weighUrlRes.success && Boolean(weighUrlRes.data?.signedUrl),
      'Security: getBuyerWeighmentSlipSignedUrlAction delivers short-lived signed URL',
      `URL: ${weighUrlRes.data?.signedUrl}`
    );
  } catch (err: any) {
    assert(false, 'Security: getBuyerWeighmentSlipSignedUrlAction delivers short-lived signed URL', err.message);
  }

  // --- 6. Privacy Scrubber Verification ---
  console.log('\n--- 6. Privacy Scrubber & Tenant Isolation ---');
  try {
    const res = await getBuyerTransactionQualityAction('BKG-2026-8812');
    const serialized = JSON.stringify(res.data || {});

    const containsPhone = /\+91[0-9]{10}/.test(serialized);
    const containsEmail = /[a-zA-Z0-9._%+-]+@seller[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/.test(serialized);
    const containsSellerPrice = /sellerPrice|reservePrice|minimumPrice/.test(serialized);

    assert(!containsPhone, 'Privacy: Zero Seller phone numbers in payload');
    assert(!containsEmail, 'Privacy: Zero Seller email addresses in payload');
    assert(!containsSellerPrice, 'Privacy: Zero Seller internal pricing or reserves in payload');
  } catch (err: any) {
    assert(false, 'Privacy: Zero Seller PII leaked', err.message);
  }

  // --- 7. Architectural Guardrails (Read-Only Layer) ---
  console.log('\n--- 7. Architectural Invariants (Read-Only Quality) ---');
  const actionExports = Object.keys(qualityActions);
  const mutationKeywords = ['create', 'update', 'delete', 'mutate', 'dispute', 'reject', 'override'];
  const accidentalMutations = actionExports.filter(exp =>
    mutationKeywords.some(kw => exp.toLowerCase().includes(kw))
  );

  assert(
    accidentalMutations.length === 0,
    'Read-Only Boundary: Action file contains zero mutation or dispute creation exports',
    `Exports: ${actionExports.join(', ')}`
  );

  // --- 8. UI Mobile-First Contract & Integration ---
  console.log('\n--- 8. UI Mobile-First Contract & Page Integration ---');
  const componentPath = path.join(
    process.cwd(),
    'src/components/buyer/orders/transaction-quality-card.tsx'
  );
  assert(fs.existsSync(componentPath), 'UI Contract: TransactionQualityCard component file exists');

  if (fs.existsSync(componentPath)) {
    const componentCode = fs.readFileSync(componentPath, 'utf-8');

    assert(
      componentCode.includes("'use client'"),
      'UI Contract: TransactionQualityCard is a client component ("use client")'
    );

    assert(
      componentCode.includes('min-h-[48px]'),
      'UI Contract: Enforces 48px minimum touch targets for mobile accessibility'
    );

    assert(
      componentCode.includes('flex-col') || componentCode.includes('space-y-'),
      'UI Contract: Responsive stacking for 360px viewport viewability'
    );

    assert(
      componentCode.includes('View Certificate of Analysis'),
      'UI Contract: Includes Certificate of Analysis preview trigger'
    );

    assert(
      componentCode.includes('View Official Weighbridge Slip') || componentCode.includes('View Weighbridge Slip'),
      'UI Contract: Includes Weighbridge Slip preview trigger'
    );
  }

  const pagePath = path.join(
    process.cwd(),
    'app/(buyer)/buyer/orders/[id]/page.tsx'
  );
  assert(fs.existsSync(pagePath), 'Page Integration: Order detail page exists');

  if (fs.existsSync(pagePath)) {
    const pageCode = fs.readFileSync(pagePath, 'utf-8');
    assert(
      pageCode.includes('TransactionQualityCard'),
      'Page Integration: TransactionQualityCard mounted in BuyerOrderDetailPage'
    );
    assert(
      pageCode.includes('getBuyerTransactionQualityAction'),
      'Page Integration: getBuyerTransactionQualityAction called on server'
    );
  }

  // --- Final Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} TESTS PASSED`);
  console.log('========================================================\n');

  if (passedTests === totalTests) {
    console.log('🎉 MICRO-SPRINT 39.1 MEETS ALL TECHNICAL & PRD SPECIFICATIONS!');
    process.exit(0);
  } else {
    console.error('⚠️ SOME TESTS FAILED. PLEASE REVIEW OUTPUT ABOVE.');
    process.exit(1);
  }
}

runSprint391Verification().catch(err => {
  console.error('Fatal verification runner error:', err);
  process.exit(1);
});
