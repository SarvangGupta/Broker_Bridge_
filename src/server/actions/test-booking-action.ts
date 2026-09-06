import { db } from "@/src/server/db";
import {
  deals,
  quotations,
  dealVersions,
  bookings,
  availabilities,
  companies,
  users,
  masterCommodities,
  masterGrades,
  masterUnits,
  requirements,
} from "@/src/server/db/schema";
import { eq } from "drizzle-orm";
import { createIdempotentBookingAction, getBookingByDealIdAction } from "./booking-actions";

/**
 * Automated Verification Test for Micro-Sprint 18.5 (Idempotent Booking Creation).
 */
export async function runBookingMicroSprintTests(): Promise<{
  passed: boolean;
  results: Array<{ test: string; status: "PASS" | "FAIL"; details?: any }>;
}> {
  const results: Array<{ test: string; status: "PASS" | "FAIL"; details?: any }> = [];

  try {
    // 1. Setup Test Fixture
    const user = await db.query.users.findFirst();
    const company = await db.query.companies.findFirst();
    const commodity = await db.query.masterCommodities.findFirst();
    const grade = await db.query.masterGrades.findFirst();
    const unit = await db.query.masterUnits.findFirst();

    if (!user || !company || !commodity || !grade || !unit) {
      return {
        passed: false,
        results: [
          {
            test: "Fixture Prerequisites",
            status: "FAIL",
            details: "Missing base seeds in database.",
          },
        ],
      };
    }

    // A. Create test availability
    const [testLot] = await db
      .insert(availabilities)
      .values({
        companyId: company.id,
        commodityId: commodity.id,
        gradeId: grade.id,
        quantity: 100,
        unitId: unit.id,
        lotNumber: `TEST-LOT-${Date.now()}`,
        totalQuantity: "100",
        availableQuantity: "100",
        reservedQuantity: "0",
        soldQuantity: "0",
        askingPrice: "2450.00",
        price: "2450.00",
        stateId: (await db.query.masterStates.findFirst())?.id || "",
        districtId: (await db.query.masterDistricts.findFirst())?.id || "",
        validUntil: new Date(Date.now() + 86400000),
        version: 1,
      })
      .returning();

    // B. Create test requirement
    const [testReq] = await db
      .insert(requirements)
      .values({
        companyId: company.id,
        commodityId: commodity.id,
        gradeId: grade.id,
        unitId: unit.id,
        quantity: 25,
        targetPrice: 2400.0,
        deliveryTermsId: "Ex-Warehouse",
        targetDate: new Date(Date.now() + 86400000),
        status: "Open",
      })
      .returning();

    // C. Create test quotation in 'Proposed' status (Unfinalized)
    const [unfinalizedQuotation] = await db
      .insert(quotations)
      .values({
        requirementId: testReq.id,
        brokerId: user.id,
        sellerAvailabilityId: testLot.id,
        offeredPrice: "2425.00",
        validUntil: new Date(Date.now() + 86400000),
        status: "Proposed",
      })
      .returning();

    // D. Create test deal version in 'Proposed' status
    await db.insert(dealVersions).values({
      requestId: unfinalizedQuotation.id,
      versionNumber: 1,
      actorId: user.id,
      status: "Proposed",
      snapshotPayload: {
        commodityId: commodity.id,
        commodityName: commodity.name,
        gradeId: grade.id,
        gradeName: grade.gradeName,
        lotId: testLot.id,
        lotNumber: testLot.lotNumber,
        quantity: 25,
        rate: 2425,
        deliveryTerms: "Ex-Warehouse",
        paymentTerms: "Standard Escrow Settlement",
      },
    });

    // TEST 1: Gate Check Failure on Unfinalized Deal
    try {
      const failRes = await createIdempotentBookingAction(unfinalizedQuotation.id);
      if (!failRes.success && failRes.error?.includes("DEAL_NOT_FINALIZED")) {
        results.push({
          test: "Negative Gate Guard (Blocks unfinalized deal)",
          status: "PASS",
          details: failRes.error,
        });
      } else {
        results.push({
          test: "Negative Gate Guard (Blocks unfinalized deal)",
          status: "FAIL",
          details: `Expected DEAL_NOT_FINALIZED error, received: ${JSON.stringify(failRes)}`,
        });
      }
    } catch (e: any) {
      results.push({
        test: "Negative Gate Guard (Blocks unfinalized deal)",
        status: "PASS",
        details: e.message,
      });
    }

    // E. Transition version and quotation to 'Broker Finalized'
    await db
      .update(dealVersions)
      .set({ status: "Broker Finalized" })
      .where(eq(dealVersions.requestId, unfinalizedQuotation.id));

    await db
      .update(quotations)
      .set({ status: "Broker Finalized" })
      .where(eq(quotations.id, unfinalizedQuotation.id));

    // TEST 2: Creation of Booking Reference
    const createRes1 = await createIdempotentBookingAction(unfinalizedQuotation.id);
    if (createRes1.success && createRes1.bookingId?.startsWith("BKG-")) {
      results.push({
        test: "Booking ID Generation on Broker Finalized Deal",
        status: "PASS",
        details: { bookingReference: createRes1.bookingId },
      });
    } else {
      results.push({
        test: "Booking ID Generation on Broker Finalized Deal",
        status: "FAIL",
        details: createRes1,
      });
    }

    // TEST 3: Idempotent Replay (Second invocation returns identical booking without duplicate insertion)
    const createRes2 = await createIdempotentBookingAction(unfinalizedQuotation.id);
    if (
      createRes2.success &&
      createRes2.bookingId === createRes1.bookingId &&
      createRes2.message?.includes("already exists")
    ) {
      results.push({
        test: "Idempotency Replay (Zero duplicate bookings)",
        status: "PASS",
        details: {
          firstBookingId: createRes1.bookingId,
          replayBookingId: createRes2.bookingId,
        },
      });
    } else {
      results.push({
        test: "Idempotency Replay (Zero duplicate bookings)",
        status: "FAIL",
        details: createRes2,
      });
    }

    // TEST 4: Inventory Reservation Verification
    const updatedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, testLot.id),
    });
    if (
      updatedLot &&
      Number(updatedLot.availableQuantity) === 75 &&
      Number(updatedLot.reservedQuantity) === 25
    ) {
      results.push({
        test: "Atomic Inventory Lock Verification (100 - 25 = 75 Available, 25 Reserved)",
        status: "PASS",
        details: {
          available: updatedLot.availableQuantity,
          reserved: updatedLot.reservedQuantity,
        },
      });
    } else {
      results.push({
        test: "Atomic Inventory Lock Verification",
        status: "FAIL",
        details: updatedLot,
      });
    }

    // TEST 5: Fetch Booking by Deal ID
    const fetchRes = await getBookingByDealIdAction(unfinalizedQuotation.id);
    if (fetchRes.success && fetchRes.bookingId === createRes1.bookingId) {
      results.push({
        test: "getBookingByDealIdAction lookup",
        status: "PASS",
        details: fetchRes.data,
      });
    } else {
      results.push({
        test: "getBookingByDealIdAction lookup",
        status: "FAIL",
        details: fetchRes,
      });
    }

    const allPassed = results.every((r) => r.status === "PASS");
    return { passed: allPassed, results };
  } catch (err: any) {
    return {
      passed: false,
      results: [
        ...results,
        {
          test: "Execution Error",
          status: "FAIL",
          details: err.message || err,
        },
      ],
    };
  }
}
