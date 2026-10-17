import {
  getVetKindCategoriesAction,
  getVetKindProductsAction,
  getVetKindProductBySlugAction,
  getVetKindDealersAction,
  submitVetKindInquiryAction,
} from '../actions/vetkind-actions';

async function runVetKindVerification() {
  console.log('========================================================');
  console.log('  VETKIND ANIMAL HEALTH INDIA: VERIFICATION SUITE');
  console.log('========================================================\n');

  let passed = 0;
  let total = 0;

  function assert(condition: boolean, title: string, detail?: string) {
    total++;
    if (condition) {
      passed++;
      console.log(`✅ [PASS] ${title}`);
      if (detail) console.log(`   └─ ${detail}`);
    } else {
      console.error(`❌ [FAIL] ${title}`);
      if (detail) console.error(`   └─ ${detail}`);
    }
  }

  // --- 1. Category Integrity ---
  console.log('--- 1. Category Integrity ---');
  const catRes = await getVetKindCategoriesAction();
  assert(catRes.success === true, 'Categories Action: Returns success');
  assert(
    Array.isArray(catRes.data) && catRes.data.length >= 5,
    'Categories Action: Returns at least 5 veterinary categories',
    `Count: ${catRes.data?.length}`
  );

  // --- 2. Product Catalogue Retrieval & Filtering ---
  console.log('\n--- 2. Product Catalogue Retrieval & Filtering ---');
  const allProductsRes = await getVetKindProductsAction();
  assert(allProductsRes.success === true, 'Products Action: Returns success');
  assert(
    (allProductsRes.data?.length || 0) >= 6,
    'Products Action: Returns initial full catalogue',
    `Found: ${allProductsRes.data?.length} products`
  );

  // Filter by category
  const nutritionRes = await getVetKindProductsAction({
    categorySlug: 'nutritional-supplements',
  });
  assert(
    (nutritionRes.data?.length || 0) > 0,
    'Category Filter: Correctly filters Nutritional Supplements',
    `Found: ${nutritionRes.data?.length} products`
  );

  // Filter by species
  const cattleRes = await getVetKindProductsAction({ species: 'Cattle' });
  assert(
    (cattleRes.data?.length || 0) > 0,
    'Species Filter: Correctly filters Cattle formulations',
    `Found: ${cattleRes.data?.length} products`
  );

  // Search query filter
  const searchRes = await getVetKindProductsAction({ query: 'calcium' });
  assert(
    (searchRes.data?.length || 0) > 0,
    'Search Filter: Resolves keyword search "calcium"',
    `Found: ${searchRes.data?.length} matches`
  );

  // --- 3. Single Product Monograph Retrieval ---
  console.log('\n--- 3. Single Product Monograph Retrieval ---');
  const slugRes = await getVetKindProductBySlugAction('vetcal-ultra-chelated-calcium');
  assert(slugRes.success === true, 'Single Product: Successfully fetches VetCal Ultra by slug');
  assert(
    slugRes.data?.sku === 'VK-CAL-001',
    'Single Product: Verifies exact SKU VK-CAL-001',
    `SKU: ${slugRes.data?.sku}`
  );
  assert(
    Boolean(slugRes.data?.composition && slugRes.data?.dosageInstructions),
    'Single Product: Contains full composition and dosage instructions'
  );

  // Unknown slug handling
  const unknownRes = await getVetKindProductBySlugAction('non-existent-product');
  assert(
    unknownRes.success === false,
    'Single Product: Safely rejects non-existent product slug'
  );

  // --- 4. Authorized Dealer & Stockist Network ---
  console.log('\n--- 4. Authorized Dealer Network ---');
  const dealersRes = await getVetKindDealersAction();
  assert(dealersRes.success === true, 'Dealers Action: Successfully returns dealers');
  assert(
    (dealersRes.data?.length || 0) >= 4,
    'Dealers Action: Returns certified regional distributors',
    `Count: ${dealersRes.data?.length}`
  );

  const haryanaDealers = await getVetKindDealersAction('Haryana');
  assert(
    (haryanaDealers.data?.length || 0) > 0,
    'Dealers Filter: Returns Haryana dairy belt stockists',
    `Count: ${haryanaDealers.data?.length}`
  );

  // --- 5. Inquiry Submission & Validation Invariants ---
  console.log('\n--- 5. Inquiry Submission & Validation ---');
  // Name validation
  const emptyNameRes = await submitVetKindInquiryAction({
    name: '',
    mobile: '9812044512',
    city: 'Karnal',
    state: 'Haryana',
    inquiryType: 'Farmer Product Enquiry',
    message: 'Valid requirement message with enough length.',
  });
  assert(
    emptyNameRes.success === false,
    'Inquiry Validation: Rejects submission with empty name'
  );

  // Mobile validation
  const invalidMobileRes = await submitVetKindInquiryAction({
    name: 'Dr. Suresh',
    mobile: '123',
    city: 'Karnal',
    state: 'Haryana',
    inquiryType: 'Farmer Product Enquiry',
    message: 'Valid requirement message with enough length.',
  });
  assert(
    invalidMobileRes.success === false,
    'Inquiry Validation: Rejects invalid mobile number'
  );

  // Short message validation
  const shortMsgRes = await submitVetKindInquiryAction({
    name: 'Dr. Suresh',
    mobile: '9812044512',
    city: 'Karnal',
    state: 'Haryana',
    inquiryType: 'Farmer Product Enquiry',
    message: 'Too short',
  });
  assert(
    shortMsgRes.success === false,
    'Inquiry Validation: Rejects message under 15 characters'
  );

  // Successful submission
  const validSubmission = await submitVetKindInquiryAction({
    name: 'Dr. Harpreet Singh',
    mobile: '9876543210',
    email: 'dr.harpreet@gmail.com',
    city: 'Ludhiana',
    state: 'Punjab',
    inquiryType: 'Veterinary Advisory',
    dairyHerdSize: '30+ Commercial Dairy',
    message: 'Requesting bulk institutional supply of VetCal Ultra and MastiLac Teat Spray for 45-cow dairy herd.',
  });
  assert(
    validSubmission.success === true,
    'Inquiry Submission: Successfully accepts valid veterinary inquiry',
    `Ref: ${validSubmission.inquiryReference}`
  );

  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passed} / ${total} PASSED`);
  console.log('========================================================');

  if (passed !== total) {
    process.exit(1);
  }
}

runVetKindVerification().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
