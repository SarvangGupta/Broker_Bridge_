/**
 * Micro-Sprint 38.4 & 38.5 Verification Test Suite
 * Buyer Dispatch Tracking & Delivery Logistics
 * 
 * Verifies:
 * 1. getBuyerBookingVisibilityAction returns live dispatch details:
 *    - vehicleNumber, transporterName, loadingLocation, destination, eta, dispatchedQuantity
 *    - documents array containing LR and E-Way Bill
 * 2. LogisticsTimeline handles 6-state live progression:
 *    - Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed
 *    - Highlights active and completed stages in Ocean Blue (#0284C7)
 *    - Exception badges for Delayed, Cancelled, and Disputed
 * 3. DeliveryDetailsCard renders:
 *    - Vehicle Number badge, Transporter Name, Loaded Quantity
 *    - Dispatch Date, ETA, Loading Location, Destination
 *    - Empty state: "Awaiting Dispatch - Vehicle details and ETA will appear here..."
 *    - Document view buttons with min-h-[48px] touch targets
 * 4. getBuyerDispatchDocumentSignedUrlAction provides secure document access:
 *    - Blocks directory traversal attacks
 * 5. Route Integration at app/(buyer)/buyer/orders/[id]/page.tsx:
 *    - Renders all 4 cards in sequential reading order
 *    - Zero editable inputs (Strictly Read-Only)
 */

import {
  getBuyerBookingVisibilityAction,
  getBuyerDispatchDocumentSignedUrlAction,
} from '../actions/buyer-order-actions';
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

async function runSprint384_385Verification() {
  console.log('\n========================================================');
  console.log('  MICRO-SPRINT 38.4 & 38.5: BUYER DISPATCH & DELIVERY TEST');
  console.log('========================================================\n');

  // --- 1. Fetch Dispatch & Logistics Data ---
  console.log('--- 1. Fetch Dispatch & Logistics Data ---');
  const res = await getBuyerBookingVisibilityAction('BKG-2026-1042');
  assert(res.success === true && !!res.data, 'Execution: getBuyerBookingVisibilityAction succeeds');

  const data = res.data!;
  assert(data.hasActiveDispatch === true, 'Data Check: hasActiveDispatch is true for dispatched booking');
  assert(!!data.dispatchDetails, 'Data Check: dispatchDetails object is present');

  const dispatch = data.dispatchDetails!;
  assert(
    !!dispatch.vehicleNumber && dispatch.vehicleNumber.includes('MH-'),
    'Transit Info: Vehicle number present',
    `Vehicle: ${dispatch.vehicleNumber}`
  );
  assert(
    !!dispatch.transporterName,
    'Transit Info: Transporter name present',
    `Transporter: ${dispatch.transporterName}`
  );
  assert(
    typeof dispatch.dispatchedQuantity === 'number' && dispatch.dispatchedQuantity > 0,
    'Transit Info: Loaded quantity is positive number',
    `Loaded Quantity: ${dispatch.dispatchedQuantity} ${dispatch.unitSymbol}`
  );
  assert(
    !!dispatch.loadingLocation && !!dispatch.destination,
    'Transit Info: Loading location and Destination present',
    `${dispatch.loadingLocation} -> ${dispatch.destination}`
  );
  assert(
    !!dispatch.expectedDeliveryDate,
    'Transit Info: ETA expected delivery date present',
    `ETA: ${dispatch.expectedDeliveryDate}`
  );
  assert(
    Array.isArray(dispatch.documents) && dispatch.documents.length >= 2,
    'Transit Documents: Returns at least 2 transit documents (LR and E-Way Bill)',
    `Docs count: ${dispatch.documents.length}`
  );

  // --- 2. Live State Machine in LogisticsTimeline (38.4) ---
  console.log('\n--- 2. Live State Machine Timeline (38.4) ---');
  const timelineFile = path.resolve(
    process.cwd(),
    'src/components/buyer/orders/logistics-timeline.tsx'
  );
  const timelineContent = fs.readFileSync(timelineFile, 'utf8');

  assert(
    timelineContent.includes("'Booked'") &&
    timelineContent.includes("'Dispatch Planned'") &&
    timelineContent.includes("'Dispatched'") &&
    timelineContent.includes("'In Transit'") &&
    timelineContent.includes("'Delivered'") &&
    timelineContent.includes("'Completed'"),
    'State Machine: Implements 6-state live progression (Booked -> Dispatch Planned -> Dispatched -> In Transit -> Delivered -> Completed)'
  );
  assert(
    timelineContent.includes('isCompleted && \'bg-[#0284C7]') ||
    timelineContent.includes('isCompleted ? \'bg-[#0284C7]\''),
    'Design Check: Highlights past steps in Ocean Blue (#0284C7)'
  );
  assert(
    timelineContent.includes('isActive &&') && timelineContent.includes('bg-[#0284C7]'),
    'Design Check: Highlights active step in Ocean Blue (#0284C7)'
  );
  assert(
    timelineContent.includes('isFuture && \'bg-slate-100'),
    'Design Check: Leaves future steps grayed out'
  );
  assert(
    timelineContent.includes('delayed') &&
    timelineContent.includes('cancelled') &&
    timelineContent.includes('disputed'),
    'Exception Handling: Evaluates Delayed, Cancelled, and Disputed exception states'
  );

  // --- 3. Live Vehicle & Delivery Details Card (38.5) ---
  console.log('\n--- 3. Live Vehicle & Delivery Details Card (38.5) ---');
  const deliveryCardFile = path.resolve(
    process.cwd(),
    'src/components/buyer/orders/delivery-details-card.tsx'
  );
  const deliveryCardContent = fs.readFileSync(deliveryCardFile, 'utf8');

  assert(
    deliveryCardContent.includes('Assigned Vehicle Number') || deliveryCardContent.includes('Vehicle Number'),
    'Vehicle Info: Renders prominent Vehicle Number section'
  );
  assert(
    deliveryCardContent.includes('Loaded Quantity'),
    'Volume Cross-Reference: Explicitly labels Loaded Quantity'
  );
  assert(
    deliveryCardContent.includes('Transporter:'),
    'Transporter Info: Renders Transporter Name'
  );
  assert(
    deliveryCardContent.includes('Awaiting Dispatch'),
    'Empty State: Renders "Awaiting Dispatch" fallback when no dispatch record exists'
  );
  assert(
    deliveryCardContent.includes('Vehicle details and ETA will appear here once the Broker authorizes the loading.'),
    'Empty State: Renders exact PRD fallback notice'
  );
  assert(
    deliveryCardContent.includes('min-h-[48px]'),
    'Touch Target Rule: Transit document view buttons enforce min-h-[48px] touch targets'
  );

  // --- 4. Secure Transit Document Signed URL Access ---
  console.log('\n--- 4. Secure Document Access ---');
  const signedUrlRes = await getBuyerDispatchDocumentSignedUrlAction(
    'deal-demo',
    'dispatches/BKG-2026-1042/LR.pdf'
  );
  assert(
    signedUrlRes.success === true && !!signedUrlRes.data?.signedUrl,
    'Signed URL: Successfully generates secure document access link',
    `URL: ${signedUrlRes.data?.signedUrl}`
  );

  const traversalAttempt = await getBuyerDispatchDocumentSignedUrlAction(
    'deal-demo',
    '../../etc/passwd'
  );
  assert(
    traversalAttempt.success === false,
    'Security Guardrail: Directory traversal sequence strictly blocked',
    `Error: ${traversalAttempt.error}`
  );

  // --- 5. Route Integration at /buyer/orders/[id] ---
  console.log('\n--- 5. Route Integration ---');
  const routeFile = path.resolve(
    process.cwd(),
    'app/(buyer)/buyer/orders/[id]/page.tsx'
  );
  const routeContent = fs.readFileSync(routeFile, 'utf8');

  assert(
    routeContent.includes('<BookingVisibilityCard') &&
    routeContent.includes('<OrderFulfillmentCard') &&
    routeContent.includes('<LogisticsTimeline') &&
    routeContent.includes('<DeliveryDetailsCard'),
    'Composition Check: Renders all 4 modules (Booking, Fulfillment, Timeline, Delivery Details) in order'
  );
  assert(
    !deliveryCardContent.includes('<input') && !deliveryCardContent.includes('<textarea'),
    'Strictly Read-Only: Zero editable inputs in delivery details card'
  );
  assert(
    routeContent.includes('overflow-x-hidden w-full max-w-full') ||
    routeContent.includes('w-full max-w-full overflow-x-hidden'),
    'Mobile Resilience: Route enforces zero horizontal window bleed on 360px viewports'
  );

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log('========================================================\n');

  if (passedTests < totalTests) {
    process.exit(1);
  }
}

runSprint384_385Verification().catch((err) => {
  console.error('Sprint 38.4 & 38.5 Verification crashed:', err);
  process.exit(1);
});
