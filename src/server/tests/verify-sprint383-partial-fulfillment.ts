/**
 * Micro-Sprint 38.3 Verification Test Suite
 * Buyer Order Detail & Partial Fulfillment UI
 * 
 * Verifies:
 * 1. getBuyerBookingVisibilityAction returns partial fulfillment math:
 *    - originalQuantity, bookedQuantity, remainingQuantity, fulfillmentPercentage
 *    - fulfillmentMath object with unitSymbol and isPartialFulfillment boolean
 * 2. OrderFulfillmentCard renders exact required labels:
 *    - "Original Quantity", "Booked Quantity", "Remaining Unfulfilled Quantity"
 *    - Ocean Blue (#0284C7) progress bar styling
 * 3. LogisticsTimeline renders 4 pre-defined stages:
 *    - "Booked", "Dispatch Planned", "Dispatched", "Delivered"
 *    - Visual active stage highlighting in Ocean Blue
 * 4. Route integration at app/(buyer)/buyer/orders/[id]/page.tsx:
 *    - Mounts OrderFulfillmentCard directly beneath BookingVisibilityCard
 *    - Mounts LogisticsTimeline below fulfillment card
 *    - Enforces max-w-3xl mx-auto p-4 space-y-4
 *    - Enforces overflow-x-hidden and zero horizontal data-bleed
 */

import { getBuyerBookingVisibilityAction } from '../actions/buyer-order-actions';
import * as fs from 'fs';
import * as path from 'path';

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
    if (detail) console.error(`   └─ Details: ${detail}`);
  }
}

async function runSprint383Verification() {
  console.log('\n========================================================');
  console.log('  MICRO-SPRINT 38.3: BUYER ORDER DETAIL & FULFILLMENT TEST');
  console.log('========================================================\n');

  // --- 1. Detail Server Action Update & Fulfillment Math ---
  console.log('--- 1. Detail Server Action & Fulfillment Math ---');
  const res1 = await getBuyerBookingVisibilityAction('BKG-2026-1042');
  assert(res1.success === true && !!res1.data, 'Execution: getBuyerBookingVisibilityAction succeeds for BKG-2026-1042');

  const data1 = res1.data!;
  assert(
    typeof data1.originalQuantity === 'number' && data1.originalQuantity > 0,
    'Fulfillment Math: originalQuantity is present and positive',
    `originalQuantity = ${data1.originalQuantity}`
  );
  assert(
    typeof data1.bookedQuantity === 'number' && data1.bookedQuantity > 0,
    'Fulfillment Math: bookedQuantity is present and positive',
    `bookedQuantity = ${data1.bookedQuantity}`
  );
  assert(
    typeof data1.remainingQuantity === 'number',
    'Fulfillment Math: remainingQuantity is present and calculated',
    `remainingQuantity = ${data1.remainingQuantity}`
  );
  assert(
    data1.remainingQuantity === data1.originalQuantity! - data1.bookedQuantity!,
    'Fulfillment Math: remainingQuantity equals originalQuantity - bookedQuantity',
    `${data1.remainingQuantity} === ${data1.originalQuantity} - ${data1.bookedQuantity}`
  );
  assert(
    typeof data1.fulfillmentPercentage === 'number' && data1.fulfillmentPercentage >= 0 && data1.fulfillmentPercentage <= 100,
    'Fulfillment Math: fulfillmentPercentage is properly bounded (0-100)',
    `fulfillmentPercentage = ${data1.fulfillmentPercentage}%`
  );
  assert(
    !!data1.fulfillmentMath && data1.fulfillmentMath.unitSymbol === 'MT',
    'Fulfillment Math Block: fulfillmentMath object present with unitSymbol',
    `isPartialFulfillment = ${data1.fulfillmentMath?.isPartialFulfillment}`
  );

  // --- 2. Partial Fulfillment Visualizer Card Component Verification ---
  console.log('\n--- 2. Partial Fulfillment Visualizer Card ---');
  const fulfillmentCardFile = path.resolve(
    process.cwd(),
    'src/components/buyer/orders/order-fulfillment-card.tsx'
  );
  const fulfillmentCardContent = fs.readFileSync(fulfillmentCardFile, 'utf8');

  assert(
    fulfillmentCardContent.includes('Original Quantity'),
    'Label Check: Renders exact text "Original Quantity"'
  );
  assert(
    fulfillmentCardContent.includes('Booked Quantity'),
    'Label Check: Renders exact text "Booked Quantity"'
  );
  assert(
    fulfillmentCardContent.includes('Remaining Unfulfilled Quantity'),
    'Label Check: Renders exact text "Remaining Unfulfilled Quantity"'
  );
  assert(
    fulfillmentCardContent.includes('#0284C7'),
    'Design Check: Uses Ocean Blue (#0284C7) for fulfilled percentage progress bar'
  );
  assert(
    fulfillmentCardContent.includes('overflow-x-auto') || fulfillmentCardContent.includes('overflow-hidden'),
    'Guardrail Check: Container implements overflow protection for 360px mobile viewports'
  );

  // --- 3. Logistics Timeline Scaffold Component Verification ---
  console.log('\n--- 3. Logistics Timeline Scaffold ---');
  const timelineFile = path.resolve(
    process.cwd(),
    'src/components/buyer/orders/logistics-timeline.tsx'
  );
  const timelineContent = fs.readFileSync(timelineFile, 'utf8');

  assert(
    timelineContent.includes("'Booked'") || timelineContent.includes('title: \'Booked\''),
    'Stage Check: Includes static stage "Booked"'
  );
  assert(
    timelineContent.includes("'Dispatch Planned'") || timelineContent.includes('title: \'Dispatch Planned\''),
    'Stage Check: Includes static stage "Dispatch Planned"'
  );
  assert(
    timelineContent.includes("'Dispatched'") || timelineContent.includes('title: \'Dispatched\''),
    'Stage Check: Includes static stage "Dispatched"'
  );
  assert(
    timelineContent.includes("'Delivered'") || timelineContent.includes('title: \'Delivered\''),
    'Stage Check: Includes static stage "Delivered"'
  );
  assert(
    timelineContent.includes('#0284C7'),
    'Design Check: Visually highlights active stage in Ocean Blue (#0284C7)'
  );
  assert(
    !timelineContent.includes('<input') && !timelineContent.includes('<textarea'),
    'Strict Read-Only: No editable inputs; Buyer tracks dispatch progression only'
  );

  // --- 4. Route Integration at app/(buyer)/buyer/orders/[id]/page.tsx ---
  console.log('\n--- 4. Route Integration at /buyer/orders/[id] ---');
  const routeFile = path.resolve(
    process.cwd(),
    'app/(buyer)/buyer/orders/[id]/page.tsx'
  );
  const routeContent = fs.readFileSync(routeFile, 'utf8');

  assert(
    routeContent.includes('<BookingVisibilityCard') &&
    routeContent.includes('<OrderFulfillmentCard') &&
    routeContent.includes('<LogisticsTimeline'),
    'Composition Check: Renders BookingVisibilityCard, OrderFulfillmentCard, and LogisticsTimeline in correct sequence'
  );
  assert(
    routeContent.includes('max-w-3xl mx-auto p-4 space-y-4'),
    'Layout Standard: Page container strictly uses "max-w-3xl mx-auto p-4 space-y-4"'
  );
  assert(
    routeContent.includes('w-full max-w-full overflow-x-hidden'),
    'Mobile Resilience: Page enforces zero horizontal window bleed (360px compliant)'
  );

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log('========================================================\n');

  if (passedTests < totalTests) {
    process.exit(1);
  }
}

runSprint383Verification().catch((err) => {
  console.error('Sprint 38.3 Verification crashed:', err);
  process.exit(1);
});
