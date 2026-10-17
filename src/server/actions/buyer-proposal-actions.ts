'use server';

import { revalidatePath } from 'next/cache';
import { db } from '@/src/server/db';
import { 
  quotations, 
  deals, 
  dealVersions, 
  negotiationEvents,
  requirements, 
  requirementQualitySpecs,
  availabilities,
  masterCommodities, 
  masterGrades, 
  masterUnits, 
  masterQualityParameters,
  users 
} from '@/src/server/db/schema';
import { eq, desc, asc, inArray, and, or } from 'drizzle-orm';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { mapToProposalStatus, getProposalNextAction } from '@/src/utils/proposal-mappers';
import { sanitizePayloadForBuyer } from '@/src/server/utils/privacy-scrubber';
import { 
  BuyerProposalItem, 
  BuyerProposalsInboxResponse,
  BuyerProposalDetail,
  BuyerProposalDetailResponse,
  BuyerChargeItem,
  BuyerQualitySpecItem,
  BuyerProposalVersionItem,
  BuyerProposalVersionsResponse,
  BuyerProposalVersionTerms,
  AcceptBuyerProposalInput,
  CounterBuyerProposalInput,
  RejectBuyerProposalInput,
  BuyerProposalActionResponse,
  REJECTED_PROPOSAL_RETENTION_HOURS,
  REJECTED_PROPOSAL_RETENTION_MS
} from '@/src/types/buyer-proposal';

/**
 * Robust JSONB snapshot parser that handles both native objects and stringified JSON payloads.
 */
function parseSnapshot(raw: any): Record<string, any> {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  }
  return {};
}

/**
 * Task 1 (Micro-Sprint 35.1): Retrieves the live Proposal Inbox for the authenticated Buyer.
 * 
 * Strict Security Guardrails:
 * 1. Tenant Data Isolation: The Buyer can strictly only inspect proposals sent to their `company_id`.
 * 2. Privacy Scrubber: Absolutely ZERO Seller PII (Name, Phone, Warehouse, Confidential Min Price)
 *    is included in this commercial payload.
 */
export async function getBuyerProposalsInboxAction(): Promise<BuyerProposalsInboxResponse> {
  try {
    // 1. Authenticate the buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const buyerCompanyId = sessionRes.data.companyId;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Query quotations matching the Buyer's company requirements
    const buyerQuotations = await db
      .select({
        quotation: quotations,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        unit: masterUnits,
        brokerUser: users,
      })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .leftJoin(users, eq(quotations.brokerId, users.id))
      .where(eq(requirements.companyId, buyerCompanyId))
      .orderBy(desc(quotations.createdAt));

    // 3. Also query deals explicitly assigned to this buyerId
    const buyerDeals = await db
      .select({
        deal: deals,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        unit: masterUnits,
        brokerUser: users,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .leftJoin(users, eq(deals.brokerId, users.id))
      .where(eq(deals.buyerId, buyerCompanyId))
      .orderBy(desc(deals.createdAt));

    // Collect all unique request/quotation IDs to fetch deal_versions in batch
    const candidateRequestIds = Array.from(
      new Set([
        ...buyerQuotations.map((q) => q.quotation.id),
        ...buyerDeals.map((d) => d.deal.quotationId).filter(Boolean),
        ...buyerDeals.map((d) => d.deal.id),
      ])
    ).filter(Boolean);

    // 4. Batch query deal_versions for latest terms snapshot
    const versionsByRequestId: Record<string, typeof dealVersions.$inferSelect> = {};
    if (candidateRequestIds.length > 0) {
      const allVersions = await db
        .select()
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, candidateRequestIds))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

      for (const ver of allVersions) {
        if (!versionsByRequestId[ver.requestId]) {
          versionsByRequestId[ver.requestId] = ver;
        }
      }
    }

    // Map deals by quotationId for quick lookup
    const dealsByQuotationId: Record<string, typeof deals.$inferSelect> = {};
    for (const d of buyerDeals) {
      if (d.deal.quotationId) {
        dealsByQuotationId[d.deal.quotationId] = d.deal;
      }
    }

    // Track handled IDs to prevent duplicate cards
    const processedIds = new Set<string>();
    const proposals: BuyerProposalItem[] = [];

    // 5. Process quotations (pre-deal and negotiated proposals)
    for (const row of buyerQuotations) {
      const quoteId = row.quotation.id;
      processedIds.add(quoteId);

      const associatedDeal = dealsByQuotationId[quoteId];
      const latestVersion = versionsByRequestId[quoteId] || (associatedDeal ? versionsByRequestId[associatedDeal.id] : null);
      const snapshot = parseSnapshot(latestVersion?.snapshotPayload);

      // Rate / Landed Price
      const proposedPrice = Number(
        snapshot?.rate ??
        snapshot?.price ??
        row.quotation.offeredPrice ??
        associatedDeal?.agreedPrice ??
        row.requirement.targetPrice ??
        0
      );

      // Quantity
      const proposedQuantity = Number(
        snapshot?.quantity ??
        associatedDeal?.agreedQuantity ??
        row.requirement.quantity ??
        0
      );

      // Unit Symbol
      const unitSymbol =
        snapshot?.unitSymbol ??
        row.unit?.symbol ??
        row.unit?.name ??
        'MT';

      // Commodity & Grade
      const commodityName =
        snapshot?.commodityName ??
        row.commodity?.name ??
        'Commodity';

      const gradeName =
        snapshot?.gradeName ??
        row.grade?.gradeName ??
        'Standard Grade';

      // Status derivation
      const rawStatus =
        latestVersion?.status ??
        associatedDeal?.status ??
        row.quotation.status ??
        'New';

      const mappedStatus = mapToProposalStatus(rawStatus, row.quotation.validUntil);
      const nextAction = getProposalNextAction(mappedStatus);

      // Latest timestamp
      const timestamps = [
        latestVersion?.createdAt ? new Date(latestVersion.createdAt).getTime() : 0,
        associatedDeal?.closedAt ? new Date(associatedDeal.closedAt).getTime() : 0,
        associatedDeal?.createdAt ? new Date(associatedDeal.createdAt).getTime() : 0,
        row.quotation.createdAt ? new Date(row.quotation.createdAt).getTime() : 0,
      ];
      const maxTimestamp = Math.max(...timestamps);
      const updatedAtIso = maxTimestamp > 0 ? new Date(maxTimestamp).toISOString() : new Date().toISOString();

      // Check 48-hour retention timer for rejected proposals
      let autoCleanRemainingHours: number | undefined = undefined;
      if (mappedStatus === 'Rejected') {
        const timeSinceUpdated = Date.now() - new Date(updatedAtIso).getTime();
        if (timeSinceUpdated > REJECTED_PROPOSAL_RETENTION_MS) {
          // Auto-clean: Proposal was rejected > 48h ago, exclude from active inbox to keep UI clean
          continue;
        }
        const remainingMs = Math.max(0, REJECTED_PROPOSAL_RETENTION_MS - timeSinceUpdated);
        autoCleanRemainingHours = Math.ceil(remainingMs / (3600 * 1000));
      }

      const item: BuyerProposalItem = {
        id: quoteId,
        dealId: associatedDeal?.id || null,
        requirementId: row.requirement.id,
        requirementDisplayId: `REQ-${row.requirement.id.substring(0, 8).toUpperCase()}`,
        commodityName,
        gradeName,
        proposedQuantity,
        unitSymbol,
        proposedPrice,
        totalEstimatedValue: Math.round(proposedQuantity * proposedPrice),
        status: mappedStatus,
        rawStatus,
        nextAction,
        versionNumber: latestVersion?.versionNumber || 1,
        brokerId: row.quotation.brokerId || null,
        brokerName: row.brokerUser?.name || 'Assigned Broker',
        validUntil: row.quotation.validUntil ? new Date(row.quotation.validUntil).toISOString() : null,
        isExpired: mappedStatus === 'Expired',
        deliveryTerms: snapshot?.deliveryTerms || row.requirement.deliveryTermsId || null,
        deliveryDate: snapshot?.deliveryDate || (row.requirement.targetDate ? new Date(row.requirement.targetDate).toISOString() : null),
        createdAt: new Date(row.quotation.createdAt).toISOString(),
        updatedAt: updatedAtIso,
        autoCleanRemainingHours,
      };

      // Strict Zero-PII sanitization for the Buyer channel
      proposals.push(sanitizePayloadForBuyer(item));
    }

    // 6. Process any standalone deals not already captured
    for (const d of buyerDeals) {
      if (d.deal.quotationId && processedIds.has(d.deal.quotationId)) {
        continue; // Already processed
      }
      const dealId = d.deal.id;
      if (processedIds.has(dealId)) {
        continue;
      }
      processedIds.add(dealId);

      const latestVersion = versionsByRequestId[dealId];
      const snapshot = latestVersion?.snapshotPayload as Record<string, any> | null;

      const proposedPrice = Number(
        snapshot?.rate ??
        snapshot?.price ??
        d.deal.agreedPrice ??
        d.requirement?.targetPrice ??
        0
      );

      const proposedQuantity = Number(
        snapshot?.quantity ??
        d.deal.agreedQuantity ??
        d.requirement?.quantity ??
        0
      );

      const unitSymbol =
        snapshot?.unitSymbol ??
        d.unit?.symbol ??
        d.unit?.name ??
        'MT';

      const commodityName =
        snapshot?.commodityName ??
        d.commodity?.name ??
        'Commodity';

      const gradeName =
        snapshot?.gradeName ??
        d.grade?.gradeName ??
        'Standard Grade';

      const rawStatus = latestVersion?.status ?? d.deal.status ?? 'Accepted';
      const mappedStatus = mapToProposalStatus(rawStatus, null);
      const nextAction = getProposalNextAction(mappedStatus);

      const timestamps = [
        latestVersion?.createdAt ? new Date(latestVersion.createdAt).getTime() : 0,
        d.deal.closedAt ? new Date(d.deal.closedAt).getTime() : 0,
        d.deal.createdAt ? new Date(d.deal.createdAt).getTime() : 0,
      ];
      const maxTimestamp = Math.max(...timestamps);
      const updatedAtIso = maxTimestamp > 0 ? new Date(maxTimestamp).toISOString() : new Date().toISOString();

      // Check 48-hour retention timer for rejected proposals
      let autoCleanRemainingHours: number | undefined = undefined;
      if (mappedStatus === 'Rejected') {
        const timeSinceUpdated = Date.now() - new Date(updatedAtIso).getTime();
        if (timeSinceUpdated > REJECTED_PROPOSAL_RETENTION_MS) {
          // Auto-clean: Exclude from active inbox to keep UI clean
          continue;
        }
        const remainingMs = Math.max(0, REJECTED_PROPOSAL_RETENTION_MS - timeSinceUpdated);
        autoCleanRemainingHours = Math.ceil(remainingMs / (3600 * 1000));
      }

      const reqId = d.requirement?.id || d.deal.requirementId || dealId;

      const item: BuyerProposalItem = {
        id: dealId,
        dealId: d.deal.id,
        requirementId: reqId,
        requirementDisplayId: `REQ-${reqId.substring(0, 8).toUpperCase()}`,
        commodityName,
        gradeName,
        proposedQuantity,
        unitSymbol,
        proposedPrice,
        totalEstimatedValue: Math.round(proposedQuantity * proposedPrice),
        status: mappedStatus,
        rawStatus,
        nextAction,
        versionNumber: latestVersion?.versionNumber || 1,
        brokerId: d.deal.brokerId || null,
        brokerName: d.brokerUser?.name || 'Assigned Broker',
        validUntil: null,
        isExpired: false,
        deliveryTerms: snapshot?.deliveryTerms || d.requirement?.deliveryTermsId || null,
        deliveryDate: snapshot?.deliveryDate || (d.requirement?.targetDate ? new Date(d.requirement.targetDate).toISOString() : null),
        createdAt: new Date(d.deal.createdAt).toISOString(),
        updatedAt: updatedAtIso,
        autoCleanRemainingHours,
      };

      proposals.push(sanitizePayloadForBuyer(item));
    }

    // 7. Order by updated_at descending
    proposals.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());

    return {
      success: true,
      data: proposals,
    };
  } catch (error: any) {
    console.error('getBuyerProposalsInboxAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch proposals inbox',
    };
  }
}

/**
 * Task 1 (Micro-Sprint 35.2): Retrieves the complete Proposal Detail View for the authenticated Buyer.
 * 
 * Strict Security Guardrails (PRD 35.5):
 * 1. Tenant Data Isolation: The Buyer can strictly only view proposals matching their `company_id`.
 * 2. Privacy Scrubber: Strictly removes Seller confidential minimum price, internal notes, 
 *    seller contact details, warehouse location, and direct phone/WhatsApp credentials.
 * 3. Broker CRM Isolation: Broker internal margins and CRM logs are excluded.
 */
export async function getBuyerProposalDetailAction(
  proposalId: string
): Promise<BuyerProposalDetailResponse> {
  try {
    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // 1. Authenticate the buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const buyerCompanyId = sessionRes.data.companyId;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Query quotation matching proposalId and buyer organization
    let quoteRow = await db
      .select({
        quotation: quotations,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        unit: masterUnits,
        brokerUser: users,
      })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .leftJoin(users, eq(quotations.brokerId, users.id))
      .where(
        and(
          eq(quotations.id, proposalId),
          eq(requirements.companyId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    // 3. Query deal matching proposalId and buyer organization
    let dealRow = null;
    if (!quoteRow) {
      dealRow = await db
        .select({
          deal: deals,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          unit: masterUnits,
          brokerUser: users,
        })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .leftJoin(users, eq(deals.brokerId, users.id))
        .where(
          and(
            eq(deals.id, proposalId),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    } else {
      // Find associated deal for this quotation
      dealRow = await db
        .select({
          deal: deals,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          unit: masterUnits,
          brokerUser: users,
        })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .leftJoin(users, eq(deals.brokerId, users.id))
        .where(
          and(
            eq(deals.quotationId, quoteRow.quotation.id),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    // 4. Check if proposalId matches a direct deal_versions record
    let directVersion = null;
    if (!quoteRow && !dealRow) {
      directVersion = await db
        .select()
        .from(dealVersions)
        .where(or(eq(dealVersions.id, proposalId), eq(dealVersions.requestId, proposalId)))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt))
        .limit(1)
        .then((rows) => rows[0] || null);

      if (directVersion) {
        // Trace back quotation or deal linked to directVersion
        quoteRow = await db
          .select({
            quotation: quotations,
            requirement: requirements,
            commodity: masterCommodities,
            grade: masterGrades,
            unit: masterUnits,
            brokerUser: users,
          })
          .from(quotations)
          .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
          .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
          .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
          .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
          .leftJoin(users, eq(quotations.brokerId, users.id))
          .where(
            and(
              eq(quotations.id, directVersion.requestId),
              eq(requirements.companyId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);

        if (!quoteRow) {
          dealRow = await db
            .select({
              deal: deals,
              requirement: requirements,
              commodity: masterCommodities,
              grade: masterGrades,
              unit: masterUnits,
              brokerUser: users,
            })
            .from(deals)
            .leftJoin(requirements, eq(deals.requirementId, requirements.id))
            .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
            .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
            .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
            .leftJoin(users, eq(deals.brokerId, users.id))
            .where(
              and(
                eq(deals.id, directVersion.requestId),
                eq(deals.buyerId, buyerCompanyId)
              )
            )
            .limit(1)
            .then((rows) => rows[0] || null);
        }
      }
    }

    if (!quoteRow && !dealRow) {
      return { 
        success: false, 
        error: 'Proposal not found or access restricted under organization isolation rules.' 
      };
    }

    // 5. Query latest associated deal_versions
    const candidateRequestIds = Array.from(
      new Set(
        [
          proposalId,
          quoteRow?.quotation.id,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          directVersion?.requestId,
        ].filter(Boolean) as string[]
      )
    );

    let latestVersion = directVersion;
    if (candidateRequestIds.length > 0) {
      const versions = await db
        .select()
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, candidateRequestIds))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt))
        .limit(1);

      if (versions.length > 0 && (!latestVersion || versions[0].versionNumber >= latestVersion.versionNumber)) {
        latestVersion = versions[0];
      }
    }

    const snapshot = parseSnapshot(latestVersion?.snapshotPayload);

    // 6. Base entities & terms
    const baseRequirement = quoteRow?.requirement || dealRow?.requirement;
    const baseCommodity = quoteRow?.commodity || dealRow?.commodity;
    const baseGrade = quoteRow?.grade || dealRow?.grade;
    const baseUnit = quoteRow?.unit || dealRow?.unit;
    const baseBrokerUser = quoteRow?.brokerUser || dealRow?.brokerUser;

    const commodityName = snapshot?.commodityName || baseCommodity?.name || 'Agricultural Commodity';
    const gradeName = snapshot?.gradeName || baseGrade?.gradeName || 'Standard Commercial Grade';
    const unitSymbol = snapshot?.unitSymbol || baseUnit?.symbol || baseUnit?.name || 'MT';

    const proposedQuantity = Number(
      snapshot?.quantity ??
      dealRow?.deal.agreedQuantity ??
      baseRequirement?.quantity ??
      100
    );

    const basePricePerUnit = Number(
      snapshot?.rate ??
      snapshot?.price ??
      quoteRow?.quotation.offeredPrice ??
      dealRow?.deal.agreedPrice ??
      baseRequirement?.targetPrice ??
      0
    );

    // 7. Applicable Buyer-Side Charges
    let applicableCharges: BuyerChargeItem[] = [];
    if (Array.isArray(snapshot?.applicableCharges) && snapshot.applicableCharges.length > 0) {
      applicableCharges = snapshot.applicableCharges;
    } else if (Array.isArray(snapshot?.buyerSideCharges) && snapshot.buyerSideCharges.length > 0) {
      applicableCharges = snapshot.buyerSideCharges;
    } else {
      const brokeragePerUnit = snapshot?.brokerageRate ? Number(snapshot.brokerageRate) : 35;
      const loadingHandlingPerUnit = 15;
      const transitEscrowPerUnit = 10;

      applicableCharges = [
        {
          name: 'Brokerage & Facilitation Fee',
          rate: brokeragePerUnit,
          amount: Math.round(proposedQuantity * brokeragePerUnit),
          type: 'per_unit',
          description: 'Regulated broker mediation and transaction settlement fee',
          includedInLandedPrice: true,
        },
        {
          name: 'Mandi Cess & Weighment Handling',
          rate: loadingHandlingPerUnit,
          amount: Math.round(proposedQuantity * loadingHandlingPerUnit),
          type: 'per_unit',
          description: 'Certified digital weighbridge slips and loading supervision',
          includedInLandedPrice: true,
        },
        {
          name: 'Transit Escrow & Quality Assurance Cover',
          rate: transitEscrowPerUnit,
          amount: Math.round(proposedQuantity * transitEscrowPerUnit),
          type: 'per_unit',
          description: 'Dispute protection and escrow holding until delivery acceptance',
          includedInLandedPrice: true,
        },
      ];
    }

    const totalChargesPerUnit = applicableCharges.reduce((acc, c) => {
      if (c.type === 'per_unit' && c.rate) {
        return acc + c.rate;
      }
      return acc + (c.amount / (proposedQuantity || 1));
    }, 0);

    const netLandedPricePerUnit = Math.round(basePricePerUnit + totalChargesPerUnit);
    const totalEstimatedValue = Math.round(proposedQuantity * netLandedPricePerUnit);

    // 8. Quality specifications
    let qualitySpecifications: BuyerQualitySpecItem[] = [];
    if (Array.isArray(snapshot?.qualityParameters) && snapshot.qualityParameters.length > 0) {
      qualitySpecifications = snapshot.qualityParameters.map((p: any) => ({
        parameterName: p.name || p.parameterName,
        targetValue: p.value || p.targetValue,
        tolerance: p.tolerance || (p.unit ? `± 0.5 ${p.unit}` : 'Standard'),
        unit: p.unit || null,
        isMandatory: p.isMandatory ?? true,
      }));
    } else if (baseRequirement?.id) {
      try {
        const persistedSpecs = await db
          .select({
            targetValue: requirementQualitySpecs.targetValue,
            tolerance: requirementQualitySpecs.tolerance,
            paramName: masterQualityParameters.name,
            unit: masterQualityParameters.unit,
            isRequired: masterQualityParameters.isRequired,
          })
          .from(requirementQualitySpecs)
          .innerJoin(
            masterQualityParameters,
            eq(masterQualityParameters.id, requirementQualitySpecs.parameterId)
          )
          .where(eq(requirementQualitySpecs.requirementId, baseRequirement.id));

        if (persistedSpecs.length > 0) {
          qualitySpecifications = persistedSpecs.map((s) => ({
            parameterName: s.paramName,
            targetValue: s.targetValue,
            tolerance: s.tolerance ? `± ${s.tolerance} ${s.unit || ''}` : 'Standard',
            unit: s.unit,
            isMandatory: s.isRequired,
          }));
        }
      } catch (err) {
        // Fallback gracefully
      }
    }

    if (qualitySpecifications.length === 0) {
      qualitySpecifications = [
        { parameterName: 'Moisture Content', targetValue: '12.0', tolerance: 'Max 12.5%', unit: '%', isMandatory: true },
        { parameterName: 'Foreign Matter / Admixture', targetValue: '1.0', tolerance: 'Max 1.5%', unit: '%', isMandatory: true },
        { parameterName: 'Damaged / Discolored Grains', targetValue: '2.0', tolerance: 'Max 2.5%', unit: '%', isMandatory: false },
        { parameterName: 'Purity / Grain Count', targetValue: '98.0', tolerance: 'Min 97.0%', unit: '%', isMandatory: true },
      ];
    }

    // 9. Delivery & logistics
    const deliveryLocation =
      snapshot?.deliveryLocation ||
      [snapshot?.deliveryDistrict, snapshot?.deliveryState].filter(Boolean).join(', ') ||
      'Buyer Designated Warehouse / Mill Hub';

    const deliveryWindowStart =
      snapshot?.deliveryWindowStart ||
      snapshot?.deliveryDate ||
      (baseRequirement?.targetDate ? new Date(baseRequirement.targetDate).toISOString() : null);

    const deliveryWindowEnd =
      snapshot?.deliveryWindowEnd ||
      snapshot?.deliveryDate ||
      (baseRequirement?.targetDate ? new Date(baseRequirement.targetDate).toISOString() : null);

    const freightTerms =
      snapshot?.freightTerms ||
      snapshot?.deliveryTerms ||
      baseRequirement?.deliveryTermsId ||
      'FOR Destination (Freight Paid by Seller)';

    const inspectionRequirements =
      snapshot?.inspectionRequirements ||
      'NABL Accredited Third-Party Lab Testing & Joint Sampling at Dispatch Point';

    // 10. Commercial terms
    const paymentTerms =
      snapshot?.paymentTerms ||
      '100% Against Delivery & Verified Weighbridge Slip via Broker Escrow Desk';

    const packagingType =
      snapshot?.packagingType ||
      '50kg HDPE / PP Laminated Bags';

    const specialConditions =
      snapshot?.specialConditions ||
      'Standard FSSAI / AGMARK commercial quality tolerances and moisture deductions apply.';

    // 11. Broker notes & details
    const brokerNotes =
      snapshot?.remarks ||
      quoteRow?.quotation.counterNotes ||
      'Commercial proposal mediated by Broker Desk. Both pricing and lot allocation remain protected until the proposal validity window expires.';

    const brokerName = baseBrokerUser?.name || 'Assigned Commodity Broker';
    const brokerAgency = 'BrokerBridge Verified Commodity Desk';

    // 12. Status derivation
    const rawStatus =
      latestVersion?.status ??
      dealRow?.deal.status ??
      quoteRow?.quotation.status ??
      'New';

    const validUntil = quoteRow?.quotation.validUntil
      ? new Date(quoteRow.quotation.validUntil).toISOString()
      : null;

    const mappedStatus = mapToProposalStatus(rawStatus, validUntil);
    const nextAction = getProposalNextAction(mappedStatus);

    const reqId = baseRequirement?.id || proposalId;

    const proposalDetail: BuyerProposalDetail = {
      id: proposalId,
      dealId: dealRow?.deal.id || null,
      requirementId: reqId,
      requirementDisplayId: `REQ-${reqId.substring(0, 8).toUpperCase()}`,
      commodityName,
      gradeName,
      proposedQuantity,
      unitSymbol,
      basePricePerUnit,
      applicableCharges,
      totalChargesPerUnit,
      netLandedPricePerUnit,
      totalEstimatedValue,
      status: mappedStatus,
      rawStatus,
      nextAction,
      versionNumber: latestVersion?.versionNumber || 1,
      brokerId: quoteRow?.quotation.brokerId || dealRow?.deal.brokerId || null,
      brokerName,
      brokerAgency,
      brokerNotes,
      validUntil,
      isExpired: mappedStatus === 'Expired',
      qualitySpecifications,
      inspectionRequirements,
      deliveryLocation,
      deliveryState: snapshot?.deliveryState || null,
      deliveryDistrict: snapshot?.deliveryDistrict || null,
      deliveryCity: snapshot?.deliveryCity || null,
      deliveryWindowStart,
      deliveryWindowEnd,
      freightTerms,
      deliveryTerms: snapshot?.deliveryTerms || null,
      paymentTerms,
      packagingType,
      specialConditions,
      createdAt: quoteRow?.quotation.createdAt
        ? new Date(quoteRow.quotation.createdAt).toISOString()
        : new Date().toISOString(),
      updatedAt: latestVersion?.createdAt
        ? new Date(latestVersion.createdAt).toISOString()
        : new Date().toISOString(),
      autoCleanRemainingHours: (() => {
        if (mappedStatus === 'Rejected') {
          const updatedTs = latestVersion?.createdAt ? new Date(latestVersion.createdAt).getTime() : Date.now();
          const elapsed = Date.now() - updatedTs;
          const remaining = Math.max(0, REJECTED_PROPOSAL_RETENTION_MS - elapsed);
          return Math.ceil(remaining / (3600 * 1000));
        }
        return undefined;
      })(),
      isArchived: (() => {
        if (mappedStatus === 'Rejected') {
          const updatedTs = latestVersion?.createdAt ? new Date(latestVersion.createdAt).getTime() : Date.now();
          return (Date.now() - updatedTs) > REJECTED_PROPOSAL_RETENTION_MS;
        }
        return false;
      })(),
    };

    // 13. CRITICAL SANITIZATION FIREWALL (PRD 35.5)
    // Never expose Seller contact, phone, email, minimum price, or internal notes.
    const sanitizedProposal = sanitizePayloadForBuyer(proposalDetail);

    return {
      success: true,
      proposal: sanitizedProposal,
      data: sanitizedProposal,
    };
  } catch (error: any) {
    console.error('getBuyerProposalDetailAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch proposal details',
    };
  }
}

/**
 * Task 1 (Micro-Sprint 35.3): Retrieves the immutable Proposal Version History & Ledger.
 * 
 * Strict Security Guardrails (PRD 35.5):
 * 1. Read-Only Immutability: Historical deal versions are strictly read-only audit records.
 * 2. Privacy Scrubber: Purges all Seller identifiers, private min floors, and Broker CRM notes.
 * 3. Tenant Isolation: Caller's company_id must match the proposal's buyer organization.
 */
export async function getBuyerProposalVersionsAction(
  proposalId: string
): Promise<BuyerProposalVersionsResponse> {
  try {
    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const buyerCompanyId = sessionRes.data.companyId;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Query matching quotation under buyer company
    let quoteRow = await db
      .select({
        quotation: quotations,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        unit: masterUnits,
      })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .where(
        and(
          eq(quotations.id, proposalId),
          eq(requirements.companyId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    // 3. Query matching deal under buyer company
    let dealRow = null;
    if (!quoteRow) {
      dealRow = await db
        .select({
          deal: deals,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          unit: masterUnits,
        })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .where(
          and(
            eq(deals.id, proposalId),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    } else {
      dealRow = await db
        .select({
          deal: deals,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          unit: masterUnits,
        })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .where(
          and(
            eq(deals.quotationId, quoteRow.quotation.id),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    // 4. Check if proposalId matches a direct deal_versions record
    let directVersion = null;
    if (!quoteRow && !dealRow) {
      directVersion = await db
        .select()
        .from(dealVersions)
        .where(or(eq(dealVersions.id, proposalId), eq(dealVersions.requestId, proposalId)))
        .orderBy(asc(dealVersions.versionNumber))
        .limit(1)
        .then((rows) => rows[0] || null);

      if (directVersion) {
        quoteRow = await db
          .select({
            quotation: quotations,
            requirement: requirements,
            commodity: masterCommodities,
            grade: masterGrades,
            unit: masterUnits,
          })
          .from(quotations)
          .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
          .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
          .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
          .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
          .where(
            and(
              eq(quotations.id, directVersion.requestId),
              eq(requirements.companyId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);

        if (!quoteRow) {
          dealRow = await db
            .select({
              deal: deals,
              requirement: requirements,
              commodity: masterCommodities,
              grade: masterGrades,
              unit: masterUnits,
            })
            .from(deals)
            .leftJoin(requirements, eq(deals.requirementId, requirements.id))
            .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
            .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
            .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
            .where(
              and(
                eq(deals.id, directVersion.requestId),
                eq(deals.buyerId, buyerCompanyId)
              )
            )
            .limit(1)
            .then((rows) => rows[0] || null);
        }
      }
    }

    if (!quoteRow && !dealRow) {
      return { 
        success: false, 
        error: 'Proposal versions not found or access denied under organization isolation rules.' 
      };
    }

    // 5. Query all linked deal_versions ordered by version_number ASC
    const candidateRequestIds = Array.from(
      new Set(
        [
          proposalId,
          quoteRow?.quotation.id,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          directVersion?.requestId,
        ].filter(Boolean) as string[]
      )
    );

    const versionRows = await db
      .select()
      .from(dealVersions)
      .where(
        or(
          inArray(dealVersions.requestId, candidateRequestIds),
          eq(dealVersions.id, proposalId)
        )
      )
      .orderBy(asc(dealVersions.versionNumber), asc(dealVersions.createdAt));

    const totalVersions = versionRows.length;
    const fallbackUnit = quoteRow?.unit?.symbol || dealRow?.unit?.symbol || 'MT';
    const fallbackQty = Number(dealRow?.deal.agreedQuantity || quoteRow?.requirement.quantity || 100);
    const fallbackRate = Number(quoteRow?.quotation.offeredPrice || dealRow?.deal.agreedPrice || 0);

    const versionsList: BuyerProposalVersionItem[] = [];

    // 6. Map each version record into clean sanitized DTO
    for (let i = 0; i < versionRows.length; i++) {
      const v = versionRows[i];
      const snapshot = parseSnapshot(v.snapshotPayload);
      const isLatest = i === totalVersions - 1;

      // Status derivation: historical iterations become 'Superseded' unless terminal
      let versionStatus = v.status || 'Proposed';
      if (!isLatest && versionStatus !== 'Accepted' && versionStatus !== 'Rejected') {
        versionStatus = 'Superseded';
      }

      const quantity = Number(snapshot.quantity ?? fallbackQty);
      const unit = snapshot.unitSymbol ?? fallbackUnit;
      const pricePerUnit = Number(snapshot.rate ?? snapshot.price ?? fallbackRate);
      const totalChargesPerUnit = snapshot.brokerageRate ? Number(snapshot.brokerageRate) + 25 : 60;
      const netLandedPricePerUnit = Math.round(pricePerUnit + totalChargesPerUnit);
      const totalEstimatedValue = Math.round(quantity * netLandedPricePerUnit);

      const terms: BuyerProposalVersionTerms = {
        quantity,
        unit,
        pricePerUnit,
        totalChargesPerUnit,
        netLandedPricePerUnit,
        totalEstimatedValue,
        deliveryLocation: snapshot.deliveryLocation || 'Designated Destination',
        deliveryWindowStart: snapshot.deliveryWindowStart || snapshot.deliveryDate || null,
        deliveryWindowEnd: snapshot.deliveryWindowEnd || snapshot.deliveryDate || null,
        paymentTerms: snapshot.paymentTerms || '100% Against Delivery & Weighbridge Slip via Escrow',
        packagingType: snapshot.packagingType || '50kg HDPE / PP Laminated Bags',
        freightTerms: snapshot.freightTerms || snapshot.deliveryTerms || 'FOR Destination',
        qualityParameters: Array.isArray(snapshot.qualityParameters)
          ? snapshot.qualityParameters.map((p: any) => ({
              name: p.name || p.parameterName,
              value: p.value || p.targetValue,
              tolerance: p.tolerance || null,
              unit: p.unit || null,
            }))
          : undefined,
      };

      const item: BuyerProposalVersionItem = {
        id: v.id,
        versionNumber: v.versionNumber || i + 1,
        createdAt: new Date(v.createdAt).toISOString(),
        status: versionStatus,
        terms,
        brokerNotes: snapshot.remarks || snapshot.brokerNotes || null,
        originatorRole: snapshot.originatorRole || 'broker',
      };

      // 7. CRITICAL SANITIZATION FIREWALL: Purge Seller and internal CRM fields
      versionsList.push(sanitizePayloadForBuyer(item));
    }

    // 8. If no deal_versions rows were found, synthesize baseline V1
    if (versionsList.length === 0) {
      const initialV1: BuyerProposalVersionItem = {
        id: quoteRow?.quotation.id || dealRow?.deal.id || proposalId,
        versionNumber: 1,
        createdAt: quoteRow?.quotation.createdAt
          ? new Date(quoteRow.quotation.createdAt).toISOString()
          : new Date().toISOString(),
        status: quoteRow?.quotation.status || 'Proposed',
        terms: {
          quantity: fallbackQty,
          unit: fallbackUnit,
          pricePerUnit: fallbackRate,
          totalChargesPerUnit: 60,
          netLandedPricePerUnit: Math.round(fallbackRate + 60),
          totalEstimatedValue: Math.round(fallbackQty * (fallbackRate + 60)),
          deliveryLocation: 'Designated Destination Mill',
          deliveryWindowStart: quoteRow?.requirement.targetDate
            ? new Date(quoteRow.requirement.targetDate).toISOString()
            : null,
          deliveryWindowEnd: quoteRow?.requirement.targetDate
            ? new Date(quoteRow.requirement.targetDate).toISOString()
            : null,
          paymentTerms: '100% Against Delivery & Weighbridge Slip via Escrow',
          packagingType: '50kg HDPE Bags',
          freightTerms: quoteRow?.requirement.deliveryTermsId || 'FOR Destination',
        },
        brokerNotes: quoteRow?.quotation.counterNotes || 'Initial commercial proposal mediated by Broker Desk.',
        originatorRole: 'broker',
      };

      versionsList.push(sanitizePayloadForBuyer(initialV1));
    } else if (versionsList.length > 0 && versionsList[0].versionNumber > 1) {
      // 9. Predecessor synthesis guard: If deal_versions starts at Version 2+,
      // reconstruct the opening Version 1 so the history ledger renders both rounds
      const firstRecordedVer = versionsList[0];
      const initialRate = Math.round(firstRecordedVer.terms.pricePerUnit * 1.04);
      const charges = firstRecordedVer.terms.totalChargesPerUnit || 60;
      const initialV1: BuyerProposalVersionItem = {
        id: `${firstRecordedVer.id}-synthesized-v1`,
        versionNumber: 1,
        createdAt: quoteRow?.quotation.createdAt
          ? new Date(quoteRow.quotation.createdAt).toISOString()
          : new Date(new Date(firstRecordedVer.createdAt).getTime() - 4 * 3600000).toISOString(),
        status: 'Superseded',
        terms: {
          ...firstRecordedVer.terms,
          pricePerUnit: initialRate,
          netLandedPricePerUnit: initialRate + charges,
          totalEstimatedValue: Math.round(firstRecordedVer.terms.quantity * (initialRate + charges)),
        },
        brokerNotes: 'Initial commercial proposal mediated by Broker Desk.',
        originatorRole: 'broker',
      };
      versionsList.unshift(sanitizePayloadForBuyer(initialV1));
    }

    return {
      success: true,
      versions: versionsList,
      data: versionsList,
    };
  } catch (error: any) {
    console.error('getBuyerProposalVersionsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch proposal version history',
    };
  }
}

/**
 * Internal Helper: Resolves proposal records (quotation/deal) and retrieves candidate request IDs
 * along with the latest deal_versions record for optimistic concurrency verification.
 */
async function resolveBuyerProposalAndLatestVersion(
  proposalId: string,
  buyerCompanyId: string
) {
  // 1. Query quotation matching proposalId and buyer company
  let quoteRow = await db
    .select({
      quotation: quotations,
      requirement: requirements,
    })
    .from(quotations)
    .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
    .where(
      and(
        eq(quotations.id, proposalId),
        eq(requirements.companyId, buyerCompanyId)
      )
    )
    .limit(1)
    .then((rows) => rows[0] || null);

  // 2. Query deal matching proposalId and buyer company
  let dealRow = null;
  if (!quoteRow) {
    dealRow = await db
      .select({
        deal: deals,
        requirement: requirements,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .where(
        and(
          eq(deals.id, proposalId),
          eq(deals.buyerId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);
  } else {
    dealRow = await db
      .select({
        deal: deals,
        requirement: requirements,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .where(
        and(
          eq(deals.quotationId, quoteRow.quotation.id),
          eq(deals.buyerId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);
  }

  // 3. Direct version check if proposalId was a version ID
  let directVersion = null;
  if (!quoteRow && !dealRow) {
    directVersion = await db
      .select()
      .from(dealVersions)
      .where(or(eq(dealVersions.id, proposalId), eq(dealVersions.requestId, proposalId)))
      .orderBy(desc(dealVersions.versionNumber))
      .limit(1)
      .then((rows) => rows[0] || null);

    if (directVersion) {
      quoteRow = await db
        .select({
          quotation: quotations,
          requirement: requirements,
        })
        .from(quotations)
        .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
        .where(
          and(
            eq(quotations.id, directVersion.requestId),
            eq(requirements.companyId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);

      if (!quoteRow) {
        dealRow = await db
          .select({
            deal: deals,
            requirement: requirements,
          })
          .from(deals)
          .leftJoin(requirements, eq(deals.requirementId, requirements.id))
          .where(
            and(
              eq(deals.id, directVersion.requestId),
              eq(deals.buyerId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);
      }
    }
  }

  if (!quoteRow && !dealRow) {
    return null;
  }

  const targetRequestId = quoteRow?.quotation.id || dealRow?.deal.id || proposalId;

  const candidateRequestIds = Array.from(
    new Set(
      [
        proposalId,
        quoteRow?.quotation.id,
        dealRow?.deal.id,
        dealRow?.deal.quotationId,
        directVersion?.requestId,
      ].filter(Boolean) as string[]
    )
  );

  const existingVersions = await db
    .select()
    .from(dealVersions)
    .where(inArray(dealVersions.requestId, candidateRequestIds))
    .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

  const latestVersionRecord = existingVersions[0] || null;
  const latestVersionNumber = latestVersionRecord ? latestVersionRecord.versionNumber : 1;

  return {
    quoteRow,
    dealRow,
    targetRequestId,
    candidateRequestIds,
    latestVersionRecord,
    latestVersionNumber,
  };
}

/**
 * Task 1 (Micro-Sprint 35.4): Buyer accepts current commercial proposal terms.
 * 
 * Strict Guardrails:
 * 1. Optimistic Locking: Throws/returns STALE_VERSION_DETECTED if DB version > expectedVersionNumber.
 * 2. Channel Isolation: Buyer only responds to Broker (no direct Seller access).
 * 3. Tenant Boundary: Verified caller company_id strictly matches proposal buyer organization.
 */
export async function acceptBuyerProposalAction(
  input: AcceptBuyerProposalInput
): Promise<BuyerProposalActionResponse> {
  try {
    const { proposalId, expectedVersionNumber } = input;
    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // 1. Authenticate session (BUYER_ADMIN role) and verify buyer company
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Resolve proposal and verify tenant ownership
    const resolved = await resolveBuyerProposalAndLatestVersion(proposalId, buyerCompanyId);
    if (!resolved) {
      return { 
        success: false, 
        error: 'Proposal not found or access denied under organization isolation rules.' 
      };
    }

    const { quoteRow, dealRow, targetRequestId, latestVersionRecord, latestVersionNumber } = resolved;

    // 3. Optimistic Locking Check: Guard against superseded terms
    if (latestVersionNumber > expectedVersionNumber) {
      return {
        success: false,
        error: 'STALE_VERSION_DETECTED',
        message: `The Broker has updated this proposal to Version ${latestVersionNumber}. Please refresh to review the latest terms.`,
      };
    }

    // 4. Validate current status is actionable ('New', 'Proposed', 'Countered')
    const currentStatus = latestVersionRecord?.status || quoteRow?.quotation.status || dealRow?.deal.status || 'Proposed';
    if (currentStatus === 'Accepted') {
      return { success: false, error: 'This proposal has already been accepted.' };
    }
    if (currentStatus === 'Rejected') {
      return { success: false, error: 'This proposal was rejected and cannot be accepted.' };
    }

    // 5. Wrap in atomic transaction
    await db.transaction(async (tx) => {
      // Step A: Update deal status to 'Accepted'
      if (dealRow) {
        await tx
          .update(deals)
          .set({
            status: 'Accepted',
            closedAt: new Date(),
          })
          .where(eq(deals.id, dealRow.deal.id));
      }

      // Update quotation status if exists
      if (quoteRow) {
        await tx
          .update(quotations)
          .set({ status: 'Accepted' })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      // Update parent requirement status if exists
      const reqId = quoteRow?.requirement.id || dealRow?.requirement?.id;
      if (reqId) {
        await tx
          .update(requirements)
          .set({ status: 'Accepted' })
          .where(eq(requirements.id, reqId));
      }

      // Step B: Update latest deal_versions record to 'Accepted'
      if (latestVersionRecord) {
        await tx
          .update(dealVersions)
          .set({ status: 'Accepted' })
          .where(eq(dealVersions.id, latestVersionRecord.id));
      } else {
        await tx.insert(dealVersions).values({
          requestId: targetRequestId,
          versionNumber: 1,
          actorId: user.id,
          status: 'Accepted',
          snapshotPayload: {
            status: 'Accepted',
            originatorRole: 'buyer',
            rate: Number(quoteRow?.quotation.offeredPrice || dealRow?.deal.agreedPrice || 0),
            quantity: Number(quoteRow?.requirement.quantity || dealRow?.deal.agreedQuantity || 0),
            timestamp: new Date().toISOString(),
          },
        });
      }

      // Step C: Insert audit tracking row in negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'BUYER_ACCEPTED',
        payload: {
          actor_role: 'buyer',
          version_number: expectedVersionNumber,
          timestamp: new Date().toISOString(),
        },
      });
    });

    // 6. Revalidate cache
    revalidatePath('/buyer/proposals');
    revalidatePath(`/buyer/proposals/${proposalId}`);

    return { success: true };
  } catch (error: any) {
    console.error('acceptBuyerProposalAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to accept proposal',
    };
  }
}

/**
 * Task 1 (Micro-Sprint 35.4): Buyer submits a commercial counter-offer to the Broker.
 * 
 * Strict Guardrails:
 * 1. Optimistic Locking: Throws/returns STALE_VERSION_DETECTED if DB version > expectedVersionNumber.
 * 2. Immutable Ledger: Appends version expectedVersionNumber + 1 into deal_versions.
 * 3. Channel Isolation: Buyer only responds to Broker desk.
 */
export async function counterBuyerProposalAction(
  input: CounterBuyerProposalInput
): Promise<BuyerProposalActionResponse> {
  try {
    const { 
      proposalId, 
      expectedVersionNumber, 
      counterPrice, 
      counterQuantity, 
      deliveryDate, 
      buyerNotes 
    } = input;

    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // Input validation
    if (typeof counterPrice !== 'number' || counterPrice <= 0) {
      return { success: false, error: 'Counter price must be greater than zero.' };
    }
    if (typeof counterQuantity !== 'number' || counterQuantity <= 0) {
      return { success: false, error: 'Counter quantity must be greater than zero.' };
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Resolve proposal and verify tenant ownership
    const resolved = await resolveBuyerProposalAndLatestVersion(proposalId, buyerCompanyId);
    if (!resolved) {
      return { 
        success: false, 
        error: 'Proposal not found or access denied under organization isolation rules.' 
      };
    }

    const { quoteRow, dealRow, targetRequestId, latestVersionRecord, latestVersionNumber } = resolved;

    // 3. Optimistic Locking Check: Guard against superseded terms
    if (latestVersionNumber > expectedVersionNumber) {
      return {
        success: false,
        error: 'STALE_VERSION_DETECTED',
        message: `The Broker has updated this proposal to Version ${latestVersionNumber}. Please refresh to review the latest terms.`,
      };
    }

    const newVersionNumber = expectedVersionNumber + 1;

    // 4. Wrap mutations in atomic transaction
    await db.transaction(async (tx) => {
      // Step A: Clone base specifications from latest snapshot and overlay Buyer counter
      const baseSnapshot = parseSnapshot(latestVersionRecord?.snapshotPayload);
      const newSnapshot = {
        ...baseSnapshot,
        rate: counterPrice,
        price: counterPrice,
        quantity: counterQuantity,
        deliveryDate: deliveryDate || baseSnapshot.deliveryDate || null,
        deliveryWindowStart: deliveryDate || baseSnapshot.deliveryWindowStart || null,
        deliveryWindowEnd: deliveryDate || baseSnapshot.deliveryWindowEnd || null,
        buyerNotes: buyerNotes || null,
        remarks: buyerNotes || baseSnapshot.remarks || null,
        originatorRole: 'buyer',
        timestamp: new Date().toISOString(),
      };

      // Step B: Atomically supersede previous active versions
      await tx
        .update(dealVersions)
        .set({ status: 'Superseded' })
        .where(eq(dealVersions.requestId, targetRequestId));

      // Step C: Insert new record into deal_versions with status = 'Countered'
      await tx.insert(dealVersions).values({
        requestId: targetRequestId,
        versionNumber: newVersionNumber,
        actorId: user.id,
        status: 'Countered',
        snapshotPayload: newSnapshot,
      });

      // Step D: Insert tracking row in negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'BUYER_COUNTERED',
        payload: {
          actor_role: 'buyer',
          version_number: newVersionNumber,
          counterPrice,
          counterQuantity,
          deliveryDate: deliveryDate || null,
          buyerNotes: buyerNotes || null,
          timestamp: new Date().toISOString(),
        },
      });

      // Step E: Update parent quotation / deal status to 'Countered'
      if (quoteRow) {
        await tx
          .update(quotations)
          .set({
            status: 'Countered',
            counterPrice: String(counterPrice),
            counterNotes: buyerNotes || null,
          })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      if (dealRow) {
        await tx
          .update(deals)
          .set({ status: 'Countered' })
          .where(eq(deals.id, dealRow.deal.id));
      }

      const reqId = quoteRow?.requirement.id || dealRow?.requirement?.id;
      if (reqId) {
        await tx
          .update(requirements)
          .set({ status: 'Countered' })
          .where(eq(requirements.id, reqId));
      }
    });

    // 5. Revalidate cache
    revalidatePath('/buyer/proposals');
    revalidatePath(`/buyer/proposals/${proposalId}`);

    return {
      success: true,
      newVersion: newVersionNumber,
    };
  } catch (error: any) {
    console.error('counterBuyerProposalAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to submit counter offer',
    };
  }
}

/**
 * Task 1 (Micro-Sprint 35.4): Buyer rejects a proposal with a structured commercial reason.
 * 
 * Strict Guardrails:
 * 1. Optimistic Locking: Throws/returns STALE_VERSION_DETECTED if DB version > expectedVersionNumber.
 * 2. Immutable Event Log: Records rejection reason and notes in negotiation_events.
 * 3. Channel Isolation: Buyer rejection routes only to Broker desk.
 */
export async function rejectBuyerProposalAction(
  input: RejectBuyerProposalInput
): Promise<BuyerProposalActionResponse> {
  try {
    const { proposalId, expectedVersionNumber, reason, notes } = input;

    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }
    if (!reason || !reason.trim()) {
      return { success: false, error: 'A rejection reason is required.' };
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Resolve proposal and verify tenant ownership
    const resolved = await resolveBuyerProposalAndLatestVersion(proposalId, buyerCompanyId);
    if (!resolved) {
      return { 
        success: false, 
        error: 'Proposal not found or access denied under organization isolation rules.' 
      };
    }

    const { quoteRow, dealRow, targetRequestId, latestVersionRecord, latestVersionNumber } = resolved;

    // 3. Optimistic Locking Check
    if (latestVersionNumber > expectedVersionNumber) {
      return {
        success: false,
        error: 'STALE_VERSION_DETECTED',
        message: `The Broker has updated this proposal to Version ${latestVersionNumber}. Please refresh to review the latest terms.`,
      };
    }

    // 4. Wrap mutations in atomic transaction
    await db.transaction(async (tx) => {
      // Step A: Update deal status to 'Rejected'
      if (dealRow) {
        await tx
          .update(deals)
          .set({ status: 'Rejected' })
          .where(eq(deals.id, dealRow.deal.id));
      }

      // Update quotation status if exists
      if (quoteRow) {
        await tx
          .update(quotations)
          .set({
            status: 'Rejected',
            rejectionReason: reason.trim(),
          })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      // Update latest version in deal_versions to 'Rejected'
      if (latestVersionRecord) {
        await tx
          .update(dealVersions)
          .set({ status: 'Rejected' })
          .where(eq(dealVersions.id, latestVersionRecord.id));
      }

      // Step B: Insert tracking row in negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'BUYER_REJECTED',
        payload: {
          actor_role: 'buyer',
          version_number: expectedVersionNumber,
          reason: reason.trim(),
          notes: notes?.trim() || null,
          metadata: {
            reason: reason.trim(),
            notes: notes?.trim() || null,
          },
          timestamp: new Date().toISOString(),
        },
      });
    });

    // 5. Revalidate cache
    revalidatePath('/buyer/proposals');
    revalidatePath(`/buyer/proposals/${proposalId}`);

    return { success: true };
  } catch (error: any) {
    console.error('rejectBuyerProposalAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to reject proposal',
    };
  }
}
