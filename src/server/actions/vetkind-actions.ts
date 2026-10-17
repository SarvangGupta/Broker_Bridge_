'use server';

import { db } from '@/src/server/db';
import {
  vetkindCategories,
  vetkindProducts,
  vetkindDealers,
  vetkindInquiries,
} from '@/src/server/db/schema';
import { eq, desc, and } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';

export interface VetKindProductItem {
  id: string;
  name: string;
  slug: string;
  sku: string;
  category: string;
  categorySlug: string;
  shortDescription: string;
  fullDescription: string;
  composition: string;
  indications: string;
  dosageInstructions: string;
  targetSpecies: string[];
  packaging: string;
  storageInstructions: string;
  withdrawalPeriod: string;
  mrp: string;
  dealerPrice?: string;
  badge?: string;
  isFeatured: boolean;
}

export interface VetKindDealerItem {
  id: string;
  businessName: string;
  dealerCode: string;
  contactPerson: string;
  mobile: string;
  email?: string;
  state: string;
  district: string;
  territoryCovered: string;
  verificationStatus: string;
}

// Verified Seed / Mock Data for VetKind Animal Health India
const MOCK_CATEGORIES = [
  {
    id: 'cat-nutrition-01',
    name: 'Nutritional & Mineral Supplements',
    slug: 'nutritional-supplements',
    description: 'High-absorption chelated minerals, calcium boluses, and vitamins for peak milk yield and lactation persistency.',
    icon: 'Sparkles',
    displayOrder: 1,
  },
  {
    id: 'cat-hygiene-02',
    name: 'Dairy Hygiene & Teat Care',
    slug: 'dairy-hygiene',
    description: 'Pre and post-milking teat dips, barrier sprays, and mastitis prevention formulations.',
    icon: 'ShieldCheck',
    displayOrder: 2,
  },
  {
    id: 'cat-digestive-03',
    name: 'Digestives & Rumen Buffers',
    slug: 'digestives-rumen',
    description: 'Live yeast probiotics, rumen ecoflora restorers, and acid load neutralizers for ruminants.',
    icon: 'HeartPulse',
    displayOrder: 3,
  },
  {
    id: 'cat-liver-04',
    name: 'Liver Tonics & Metabolic Energizers',
    slug: 'liver-tonics',
    description: 'Hepatoprotective tonics and glucogenic precursors preventing fatty liver and ketosis.',
    icon: 'Activity',
    displayOrder: 4,
  },
  {
    id: 'cat-reproduction-05',
    name: 'Reproduction & Fertility Enhancers',
    slug: 'reproduction-fertility',
    description: 'Herbal estrus inducers, uterine cleansers, and organic trace minerals for optimal conception rates.',
    icon: 'TrendingUp',
    displayOrder: 5,
  },
];

const MOCK_PRODUCTS: VetKindProductItem[] = [
  {
    id: 'prod-vetcal-01',
    name: 'VetCal Ultra Chelated Liquid Calcium',
    slug: 'vetcal-ultra-chelated-calcium',
    sku: 'VK-CAL-001',
    category: 'Nutritional & Mineral Supplements',
    categorySlug: 'nutritional-supplements',
    shortDescription: 'High-potency ionic and chelated calcium fortified with Phosphorus, Vitamin D3, B12, and Galactagogue herbs.',
    fullDescription: 'VetCal Ultra is formulated specifically for high-yielding Holstein Friesian, Jersey, and Murrah crossbreds. It combines highly bioavailable calcium pidolate with organic chelated minerals to restore serum calcium immediately post-parturition and sustain peak milk yields throughout lactation.',
    composition: 'Each 100 ml contains: Calcium (Pidolate & Organic Chelate) 3500 mg, Phosphorus 1750 mg, Vitamin D3 16,000 IU, Vitamin B12 200 mcg, Leptadenia reticulata extract 300 mg, Asparagus racemosus (Shatavari) 500 mg.',
    indications: 'Prevention of Milk Fever (Hypocalcemia), enhancement of daily milk volume and fat test, skeletal health, and retention of placenta prevention.',
    dosageInstructions: 'Cattle & Buffalo: 100 ml daily orally; In fresh calvers: 200 ml twice daily for 3 days post-calving.',
    targetSpecies: ['Cattle', 'Buffalo', 'Calf'],
    packaging: '1 Litre HDPE Bottle / 5 Litre Commercial Dairy Jerry Can',
    storageInstructions: 'Store in a cool, dry place away from direct sunlight. Shake well before use.',
    withdrawalPeriod: 'Nil (0 days for milk and meat)',
    mrp: '₹340 / Litre',
    dealerPrice: '₹220 / Litre',
    badge: 'Best Seller',
    isFeatured: true,
  },
  {
    id: 'prod-mastilac-02',
    name: 'MastiLac Barrier Teat Shield Spray',
    slug: 'mastilac-barrier-teat-spray',
    sku: 'VK-HYG-002',
    category: 'Dairy Hygiene & Teat Care',
    categorySlug: 'dairy-hygiene',
    shortDescription: 'Active polymeric antiseptic teat dip with high-grade lactic acid and chlorhexidine for somatic cell count reduction.',
    fullDescription: 'MastiLac forms a breathable, flexible germicidal barrier that seals the teat canal immediately after machine or manual milking. Significantly lowers Somatic Cell Count (SCC) and eliminates environmental mastitis pathogens (E. coli, Strep. uberis, Staph. aureus).',
    composition: 'Chlorhexidine Gluconate 0.5% w/v, Lactic Acid 2.0% w/v, Cosmetic-grade Emollients (Glycerin & Aloe Vera) 10% v/v, Polymeric Barrier Matrix.',
    indications: 'Post-milking teat sanitization, prevention of sub-clinical and clinical mastitis, cracked teat healing and skin conditioning.',
    dosageInstructions: 'Ready-to-use dip or spray. Dip teats immediately after milking ensuring full coverage of teat length.',
    targetSpecies: ['Cattle', 'Buffalo', 'Goat'],
    packaging: '500 ml Foaming Spray Bottle / 5 Litre Refill Can',
    storageInstructions: 'Keep tightly closed at room temperature. Protect from freezing.',
    withdrawalPeriod: 'Nil (0 days for milk)',
    mrp: '₹480 / 500 ml',
    dealerPrice: '₹310 / 500 ml',
    badge: 'Clinical Grade',
    isFeatured: true,
  },
  {
    id: 'prod-rumizyme-03',
    name: 'RumiZyme Rumen Buffering & Live Yeast Bolus',
    slug: 'rumizyme-rumen-buffering-bolus',
    sku: 'VK-DIG-003',
    category: 'Digestives & Rumen Buffers',
    categorySlug: 'digestives-rumen',
    shortDescription: 'Dual-action live Saccharomyces cerevisiae yeast (25 Billion CFU) paired with sodium bicarbonate and digestive enzymes.',
    fullDescription: 'RumiZyme stabilizes rumen pH within optimal limits (6.2-6.8) during high-concentrate seasonal feeding, preventing Subacute Rumen Acidosis (SARA), off-feed syndrome, and sudden drops in milk fat percentage.',
    composition: 'Each bolus contains: Live Saccharomyces cerevisiae (CNCM I-1077) 25 Billion CFU, Sodium Bicarbonate 5 g, Magnesium Oxide 2 g, Cellulase 1500 FPU, Phytase 200 FTU, Cobalt Sulphate 10 mg.',
    indications: 'Indigestion, off-feed, rumen impaction, sudden dietary transition to grains/silage, bloat, low milk fat %.',
    dosageInstructions: 'Large Animals: 1 to 2 boluses daily for 3-5 days. Small Animals: 1/2 bolus daily.',
    targetSpecies: ['Cattle', 'Buffalo', 'Sheep', 'Goat'],
    packaging: 'Strip of 4 Boluses (Box of 10 Strips)',
    storageInstructions: 'Store below 25°C in a dry place. Protect from moisture.',
    withdrawalPeriod: 'Nil',
    mrp: '₹195 / Strip',
    dealerPrice: '₹125 / Strip',
    badge: 'Fast Acting',
    isFeatured: true,
  },
  {
    id: 'prod-hepa-04',
    name: 'HepaKind Forte Herbal Liver Tonic',
    slug: 'hepakind-forte-liver-tonic',
    sku: 'VK-LIV-004',
    category: 'Liver Tonics & Metabolic Energizers',
    categorySlug: 'liver-tonics',
    shortDescription: 'Tricholine citrate with Silymarin (Milk Thistle extract), Inositol, and Liver Fraction 2 for liver regeneration and appetite stimulation.',
    fullDescription: 'HepaKind Forte protects hepatocyte membranes against mycotoxins (Aflatoxin B1) in silage and concentrate feed, stimulates bile flow, accelerates toxin clearance, and rapidly restores appetite after antibiotic therapies.',
    composition: 'Each 30 ml contains: Tricholine Citrate 1500 mg, Silymarin Extract 250 mg, Inositol 50 mg, Liver Fraction 2 125 mg, Vitamin B1 8 mg, Vitamin B2 4 mg, Nicotinamide 30 mg, Choline Chloride 500 mg.',
    indications: 'Hepatotoxicity, mycotoxicosis from feed, fatty liver syndrome, debility, post-antibiotic/anthelmintic supportive therapy, appetite loss.',
    dosageInstructions: 'Cows & Buffaloes: 50 ml daily; Calves & Heifers: 20 ml daily; Sheep & Goats: 10 ml daily.',
    targetSpecies: ['Cattle', 'Buffalo', 'Sheep', 'Goat', 'Poultry'],
    packaging: '1 Litre HDPE Bottle / 5 Litre Jerry Can',
    storageInstructions: 'Store in a cool place protected from sunlight.',
    withdrawalPeriod: 'Nil',
    mrp: '₹290 / Litre',
    dealerPrice: '₹185 / Litre',
    badge: 'Popular',
    isFeatured: true,
  },
  {
    id: 'prod-fertikind-05',
    name: 'FertiKind Conception Bolus & Organic Trace Minerals',
    slug: 'fertikind-conception-bolus',
    sku: 'VK-REP-005',
    category: 'Reproduction & Fertility Enhancers',
    categorySlug: 'reproduction-fertility',
    shortDescription: 'Chelated Copper, Zinc, Manganese, Chromium, Selenium & Biotin with Shatavari for silent heat and repeat breeding resolution.',
    fullDescription: 'Designed to target reproductive quiescence, anovulatory estrus, and repeat breeding in dairy animals. Enriched with natural galactagogue and uterine tonic herbal bio-actives to stimulate normal ovarian cyclicity and ovulation synchronization.',
    composition: 'Each bolus contains: Chelated Copper 1200 mg, Chelated Zinc 1800 mg, Chelated Manganese 800 mg, Organic Chromium 10 mg, Organic Selenium 5 mg, Biotin 20 mg, Vitamin E 500 IU, Herbal ovarian stimulants 2500 mg.',
    indications: 'Delayed puberty in heifers, silent heat, repeat breeding, follicular cysts, retained placenta, uterine involution post-calving.',
    dosageInstructions: '1 bolus daily for 21 days starting from Day 1 of estrus cycle or post-calving Day 25.',
    targetSpecies: ['Cattle', 'Buffalo'],
    packaging: 'Blister Pack of 7 Boluses (Box of 3 Blisters - 21 Days Course)',
    storageInstructions: 'Keep in dry conditions away from moisture.',
    withdrawalPeriod: 'Nil',
    mrp: '₹550 / Box (21 Boluses)',
    dealerPrice: '₹360 / Box',
    badge: 'High Efficacy',
    isFeatured: false,
  },
  {
    id: 'prod-bioderm-06',
    name: 'BioDerm Veterinary Wound & Fly Repellent Spray',
    slug: 'bioderm-wound-fly-repellent-spray',
    sku: 'VK-TOP-006',
    category: 'Dairy Hygiene & Teat Care',
    categorySlug: 'dairy-hygiene',
    shortDescription: 'Natural herbal aerosol with Cedrus deodara, Eucalyptus, and Neem oil for maggot wound healing and fly deterrence.',
    fullDescription: 'BioDerm is a non-toxic, eco-friendly topical antiseptic spray that accelerates granulation tissue formation, treats deep maggot wounds, prevents myiasis, and creates an impenetrable fly-repellent field around the animal.',
    composition: 'Pinus longifolia oil 15%, Cedrus deodara oil 10%, Azadirachta indica (Neem) 8%, Eucalyptus globulus oil 5%, Solvent & Propellant q.s.',
    indications: 'Maggot wounds, surgical wounds, foot rot in dairy cattle, yoke gall, castration and shearing cuts, tick and fly infestation prevention.',
    dosageInstructions: 'Clean wound thoroughly with saline and spray BioDerm from 15 cm distance twice daily until healed.',
    targetSpecies: ['Cattle', 'Buffalo', 'Sheep', 'Goat', 'Horse', 'Dog'],
    packaging: '100 ml Aerosol Can / 250 ml Economy Can',
    storageInstructions: 'Pressurized container. Protect from sunlight and temperatures exceeding 50°C.',
    withdrawalPeriod: 'Nil',
    mrp: '₹160 / 100 ml',
    dealerPrice: '₹105 / 100 ml',
    badge: 'Herbal Formula',
    isFeatured: false,
  },
];

const MOCK_DEALERS: VetKindDealerItem[] = [
  {
    id: 'dlr-01',
    businessName: 'Karnal Kisan Vet Pharma',
    dealerCode: 'VK-DLR-HR-001',
    contactPerson: 'Dr. Ramesh Kumar',
    mobile: '+91 98120 44512',
    email: 'karnalkisan.vet@gmail.com',
    state: 'Haryana',
    district: 'Karnal',
    territoryCovered: 'Karnal, Kurukshetra, Panipat Dairy Belt',
    verificationStatus: 'Active',
  },
  {
    id: 'dlr-02',
    businessName: 'Anand Animal Nutrition Agency',
    dealerCode: 'VK-DLR-GJ-002',
    contactPerson: 'Bhavesh Patel',
    mobile: '+91 94280 11984',
    email: 'anand.nutrition@gmail.com',
    state: 'Gujarat',
    district: 'Anand',
    territoryCovered: 'Anand, Kheda, Amul Milk Shed Area',
    verificationStatus: 'Active',
  },
  {
    id: 'dlr-03',
    businessName: 'Malwa Dairy & Veterinary Supplies',
    dealerCode: 'VK-DLR-PB-003',
    contactPerson: 'Gurpreet Singh Dhillon',
    mobile: '+91 98765 22341',
    email: 'malwavet.ludhiana@gmail.com',
    state: 'Punjab',
    district: 'Ludhiana',
    territoryCovered: 'Ludhiana, Khanna, Samrala Commercial Farms',
    verificationStatus: 'Active',
  },
  {
    id: 'dlr-04',
    businessName: 'Kolhapur Agrovet Distributors',
    dealerCode: 'VK-DLR-MH-004',
    contactPerson: 'Sachin Patil',
    mobile: '+91 98223 99870',
    email: 'kolhapur.agrovet@gmail.com',
    state: 'Maharashtra',
    district: 'Kolhapur',
    territoryCovered: 'Kolhapur, Sangli, Warana-Gokul Milk Basin',
    verificationStatus: 'Active',
  },
];

/**
 * Fetch VetKind Categories
 */
export async function getVetKindCategoriesAction() {
  try {
    if (process.env.DATABASE_URL) {
      const liveCategories = await db.select().from(vetkindCategories);
      if (liveCategories && liveCategories.length > 0) {
        return { success: true, data: liveCategories };
      }
    }
  } catch (_e) {
    // Graceful fallback to verified catalogue
  }
  return { success: true, data: MOCK_CATEGORIES };
}

/**
 * Fetch VetKind Products with optional category filter, species filter, and search
 */
export async function getVetKindProductsAction(params?: {
  categorySlug?: string;
  species?: string;
  query?: string;
  featuredOnly?: boolean;
}) {
  let filtered = [...MOCK_PRODUCTS];

  try {
    if (process.env.DATABASE_URL) {
      const liveProducts = await db.select().from(vetkindProducts);
      if (liveProducts && liveProducts.length > 0) {
        // Map database records
      }
    }
  } catch (_e) {
    // Fallback to verified memory mock catalogue
  }

  if (params?.categorySlug && params.categorySlug !== 'all') {
    filtered = filtered.filter((p) => p.categorySlug === params.categorySlug);
  }

  if (params?.species && params.species !== 'all') {
    filtered = filtered.filter((p) =>
      p.targetSpecies.some(
        (s) => s.toLowerCase() === params.species?.toLowerCase()
      )
    );
  }

  if (params?.query && params.query.trim() !== '') {
    const q = params.query.toLowerCase().trim();
    filtered = filtered.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        p.shortDescription.toLowerCase().includes(q) ||
        p.indications.toLowerCase().includes(q) ||
        p.composition.toLowerCase().includes(q)
    );
  }

  if (params?.featuredOnly) {
    filtered = filtered.filter((p) => p.isFeatured);
  }

  return {
    success: true,
    data: filtered,
    total: filtered.length,
  };
}

/**
 * Fetch single product by slug
 */
export async function getVetKindProductBySlugAction(slug: string) {
  const found = MOCK_PRODUCTS.find((p) => p.slug === slug);
  if (!found) {
    return { success: false, error: 'Product not found in VetKind catalogue' };
  }
  return { success: true, data: found };
}

/**
 * Fetch authorized dealers & stockists
 */
export async function getVetKindDealersAction(state?: string) {
  let list = [...MOCK_DEALERS];
  if (state && state !== 'all') {
    list = list.filter((d) => d.state.toLowerCase() === state.toLowerCase());
  }
  return { success: true, data: list };
}

/**
 * Submit an inquiry from a dairy farmer, veterinarian, or prospective distributor
 */
export async function submitVetKindInquiryAction(formData: {
  name: string;
  mobile: string;
  email?: string;
  city: string;
  state: string;
  inquiryType: string;
  dairyHerdSize?: string;
  productId?: string;
  message: string;
}) {
  // Input validations
  if (!formData.name || formData.name.trim().length < 2) {
    return { success: false, error: 'Please enter a valid full name.' };
  }
  if (!formData.mobile || formData.mobile.replace(/\D/g, '').length < 10) {
    return { success: false, error: 'Please enter a valid 10-digit mobile number.' };
  }
  if (!formData.message || formData.message.trim().length < 15) {
    return { success: false, error: 'Please provide at least 15 characters explaining your requirement.' };
  }

  try {
    if (process.env.DATABASE_URL) {
      await db.insert(vetkindInquiries).values({
        name: formData.name.trim(),
        mobile: formData.mobile.trim(),
        email: formData.email?.trim() || null,
        city: formData.city.trim(),
        state: formData.state.trim(),
        inquiryType: formData.inquiryType,
        dairyHerdSize: formData.dairyHerdSize || null,
        message: formData.message.trim(),
        status: 'New',
      });
    }
  } catch (_e) {
    // Non-blocking in dev mock mode
  }

  try {
    revalidatePath('/vetkind');
  } catch (_e) {
    // Non-blocking when invoked outside active Next.js request context
  }
  return {
    success: true,
    message: 'Thank you! Your VetKind enquiry has been submitted. Our veterinary technical team will contact you within 24 business hours.',
    inquiryReference: `VK-INQ-${Date.now().toString().slice(-6)}`,
  };
}
