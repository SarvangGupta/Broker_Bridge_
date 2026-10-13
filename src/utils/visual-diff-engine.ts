import React from 'react';
import {
  FinalDealCommercialTerms,
  BuyerQualitySpec,
  DealConfirmationStatus,
} from '@/src/types/buyer-deal-review';

/**
 * Maps raw database and version status to the locked 5-state confirmation lifecycle.
 */
export function mapToDealConfirmationStatus(
  rawStatus?: string | null,
  versionStatus?: string | null
): DealConfirmationStatus {
  const normRaw = (rawStatus || '').toLowerCase().trim();
  const normVer = (versionStatus || '').toLowerCase().trim();

  if (normVer.includes('buyer confirmed') || normRaw.includes('buyer confirmed')) {
    return 'Buyer Confirmed';
  }
  if (normVer.includes('seller confirmed') || normRaw.includes('seller confirmed')) {
    return 'Awaiting Buyer Confirmation';
  }
  if (
    normRaw === 'confirmed' ||
    normRaw === 'booked' ||
    normRaw === 'finalized' ||
    normVer === 'confirmed' ||
    normVer === 'broker finalized'
  ) {
    return 'Confirmed';
  }
  if (
    normRaw.includes('amendment') ||
    normVer.includes('amendment') ||
    normVer === 'countered' ||
    normRaw === 'amendment required'
  ) {
    return 'Amendment Required';
  }
  if (
    normRaw.includes('awaiting seller') ||
    normVer.includes('awaiting seller')
  ) {
    return 'Awaiting Seller Confirmation';
  }

  // Default initial confirmation state when broker presents final deal
  return 'Awaiting Buyer Confirmation';
}

/**
 * Normalizes strings for robust equality comparison.
 */
export function normalizeDiffString(val: any): string {
  if (val === null || val === undefined) return '';
  return String(val).trim();
}

/**
 * Checks if two numbers are materially different.
 */
export function isNumberChanged(current: number, previous?: number | null): boolean {
  if (previous === undefined || previous === null || isNaN(previous)) return false;
  return Math.abs(current - previous) > 0.001;
}

/**
 * Checks if two strings are materially different.
 */
export function isStringChanged(current: any, previous?: any): boolean {
  if (previous === undefined || previous === null) return false;
  const c = normalizeDiffString(current).toLowerCase();
  const p = normalizeDiffString(previous).toLowerCase();
  return c !== p;
}

/**
 * Formats a currency number in standard Indian Rupee format (₹).
 */
export function formatCurrencyINR(amount: number): string {
  if (isNaN(amount)) return '₹0';
  return `₹${Math.round(amount).toLocaleString('en-IN')}`;
}

/**
 * Formats a quantity with unit.
 */
export function formatQuantityWithUnit(qty: number, unit: string = 'MT'): string {
  if (isNaN(qty)) return `0 ${unit}`;
  return `${Number(qty).toLocaleString('en-IN')} ${unit}`;
}

/**
 * Formats date into readable string.
 */
export function formatDisplayDate(dateStr: string | null | undefined): string {
  if (!dateStr) return 'Not Specified';
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return String(dateStr);
    return d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  } catch {
    return String(dateStr);
  }
}

export interface FieldDiffResult {
  current: string;
  previous: string | null;
  isChanged: boolean;
}

export interface DealTermsDiffReport {
  hasPrevious: boolean;
  commodity: FieldDiffResult;
  grade: FieldDiffResult;
  quantity: FieldDiffResult;
  basePrice: FieldDiffResult;
  netLandedPrice: FieldDiffResult;
  totalEstimatedValue: FieldDiffResult;
  deliveryLocation: FieldDiffResult;
  deliveryWindow: FieldDiffResult;
  paymentTerms: FieldDiffResult;
  packagingType: FieldDiffResult;
  freightTerms: FieldDiffResult;
  inspectionRequirements: FieldDiffResult;
  specialConditions: FieldDiffResult;
  qualityDiffs: {
    parameterName: string;
    current: string;
    previous: string | null;
    isChanged: boolean;
  }[];
}

/**
 * Computes field-by-field diff between current and previous commercial snapshots.
 */
export function computeDealTermsDiff(
  current: FinalDealCommercialTerms,
  previous?: FinalDealCommercialTerms | null
): DealTermsDiffReport {
  const hasPrevious = Boolean(previous);

  // Commodity
  const commodityChanged = hasPrevious && isStringChanged(current.commodityName, previous?.commodityName);
  const commodityDiff: FieldDiffResult = {
    current: current.commodityName,
    previous: hasPrevious && commodityChanged ? previous!.commodityName : null,
    isChanged: commodityChanged,
  };

  // Grade
  const gradeChanged = hasPrevious && isStringChanged(current.gradeName, previous?.gradeName);
  const gradeDiff: FieldDiffResult = {
    current: current.gradeName,
    previous: hasPrevious && gradeChanged ? previous!.gradeName : null,
    isChanged: gradeChanged,
  };

  // Quantity
  const quantityChanged = hasPrevious && isNumberChanged(current.quantity, previous?.quantity);
  const quantityDiff: FieldDiffResult = {
    current: formatQuantityWithUnit(current.quantity, current.unitSymbol),
    previous: hasPrevious && quantityChanged ? formatQuantityWithUnit(previous!.quantity, previous!.unitSymbol) : null,
    isChanged: quantityChanged,
  };

  // Base Price
  const basePriceChanged = hasPrevious && isNumberChanged(current.basePricePerUnit, previous?.basePricePerUnit);
  const basePriceDiff: FieldDiffResult = {
    current: `${formatCurrencyINR(current.basePricePerUnit)} / ${current.unitSymbol}`,
    previous: hasPrevious && basePriceChanged ? `${formatCurrencyINR(previous!.basePricePerUnit)} / ${previous!.unitSymbol}` : null,
    isChanged: basePriceChanged,
  };

  // Net Landed Price
  const netLandedChanged = hasPrevious && isNumberChanged(current.netLandedPricePerUnit, previous?.netLandedPricePerUnit);
  const netLandedDiff: FieldDiffResult = {
    current: `${formatCurrencyINR(current.netLandedPricePerUnit)} / ${current.unitSymbol}`,
    previous: hasPrevious && netLandedChanged ? `${formatCurrencyINR(previous!.netLandedPricePerUnit)} / ${previous!.unitSymbol}` : null,
    isChanged: netLandedChanged,
  };

  // Total Estimated Value
  const totalValChanged = hasPrevious && isNumberChanged(current.totalEstimatedValue, previous?.totalEstimatedValue);
  const totalValDiff: FieldDiffResult = {
    current: formatCurrencyINR(current.totalEstimatedValue),
    previous: hasPrevious && totalValChanged ? formatCurrencyINR(previous!.totalEstimatedValue) : null,
    isChanged: totalValChanged,
  };

  // Delivery Location
  const deliveryLocChanged = hasPrevious && isStringChanged(current.deliveryLocation, previous?.deliveryLocation);
  const deliveryLocDiff: FieldDiffResult = {
    current: current.deliveryLocation || 'Buyer Warehouse / Destination Hub',
    previous: hasPrevious && deliveryLocChanged ? (previous?.deliveryLocation || 'Buyer Destination') : null,
    isChanged: deliveryLocChanged,
  };

  // Delivery Window
  const currentWindow = [
    formatDisplayDate(current.deliveryWindowStart || current.deliveryDate),
    formatDisplayDate(current.deliveryWindowEnd || current.deliveryDate),
  ].filter(Boolean).join(' → ');

  const prevWindow = previous
    ? [
        formatDisplayDate(previous.deliveryWindowStart || previous.deliveryDate),
        formatDisplayDate(previous.deliveryWindowEnd || previous.deliveryDate),
      ].filter(Boolean).join(' → ')
    : null;

  const windowChanged = hasPrevious && isStringChanged(currentWindow, prevWindow);
  const deliveryWindowDiff: FieldDiffResult = {
    current: currentWindow,
    previous: hasPrevious && windowChanged ? prevWindow : null,
    isChanged: windowChanged,
  };

  // Payment Terms
  const paymentChanged = hasPrevious && isStringChanged(current.paymentTerms, previous?.paymentTerms);
  const paymentDiff: FieldDiffResult = {
    current: current.paymentTerms,
    previous: hasPrevious && paymentChanged ? previous!.paymentTerms : null,
    isChanged: paymentChanged,
  };

  // Packaging Type
  const packagingChanged = hasPrevious && isStringChanged(current.packagingType, previous?.packagingType);
  const packagingDiff: FieldDiffResult = {
    current: current.packagingType,
    previous: hasPrevious && packagingChanged ? previous!.packagingType : null,
    isChanged: packagingChanged,
  };

  // Freight Terms
  const freightChanged = hasPrevious && isStringChanged(current.freightTerms, previous?.freightTerms);
  const freightDiff: FieldDiffResult = {
    current: current.freightTerms,
    previous: hasPrevious && freightChanged ? previous!.freightTerms : null,
    isChanged: freightChanged,
  };

  // Inspection Requirements
  const inspectionChanged = hasPrevious && isStringChanged(current.inspectionRequirements, previous?.inspectionRequirements);
  const inspectionDiff: FieldDiffResult = {
    current: current.inspectionRequirements,
    previous: hasPrevious && inspectionChanged ? previous!.inspectionRequirements : null,
    isChanged: inspectionChanged,
  };

  // Special Conditions
  const conditionsChanged = hasPrevious && isStringChanged(current.specialConditions, previous?.specialConditions);
  const conditionsDiff: FieldDiffResult = {
    current: current.specialConditions || 'Standard FSSAI and Indian mandi commercial bylaws apply.',
    previous: hasPrevious && conditionsChanged ? (previous?.specialConditions || 'Standard terms') : null,
    isChanged: conditionsChanged,
  };

  // Quality Parameters Diff
  const qualityDiffs: DealTermsDiffReport['qualityDiffs'] = [];
  const currentParams = current.qualityParameters || [];
  const prevParams = previous?.qualityParameters || [];

  for (const curr of currentParams) {
    const matchedPrev = prevParams.find(
      (p) => normalizeDiffString(p.parameterName).toLowerCase() === normalizeDiffString(curr.parameterName).toLowerCase()
    );

    const currStr = `${curr.targetValue} ${curr.unit || ''} ${curr.tolerance ? `(${curr.tolerance})` : ''}`.trim();
    const prevStr = matchedPrev
      ? `${matchedPrev.targetValue} ${matchedPrev.unit || ''} ${matchedPrev.tolerance ? `(${matchedPrev.tolerance})` : ''}`.trim()
      : null;

    const isChanged = Boolean(matchedPrev && isStringChanged(currStr, prevStr));

    qualityDiffs.push({
      parameterName: curr.parameterName,
      current: currStr,
      previous: hasPrevious && isChanged ? prevStr : null,
      isChanged,
    });
  }

  return {
    hasPrevious,
    commodity: commodityDiff,
    grade: gradeDiff,
    quantity: quantityDiff,
    basePrice: basePriceDiff,
    netLandedPrice: netLandedDiff,
    totalEstimatedValue: totalValDiff,
    deliveryLocation: deliveryLocDiff,
    deliveryWindow: deliveryWindowDiff,
    paymentTerms: paymentDiff,
    packagingType: packagingDiff,
    freightTerms: freightDiff,
    inspectionRequirements: inspectionDiff,
    specialConditions: conditionsDiff,
    qualityDiffs,
  };
}
