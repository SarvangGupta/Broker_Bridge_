import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/master_requirement_data.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

const String maizeId = '20000000-0000-0000-0000-000000000001';
const String wheatId = '20000000-0000-0000-0000-000000000002';
const String soybeanId = '20000000-0000-0000-0000-000000000003';
const String dalId = 'a732266b-b30d-4688-8519-8b3e9784685e';
const String riceId = '56809459-2a02-4f15-b061-1cb7c660da7e';
const String inactiveMaizeId = '97eccc57-7e80-435b-a51d-32700a727804';
const String inactiveWheatId = '13a5208a-7bcd-48b8-adc8-6c0f0a136c13';

/// Product Master rows as returned by PostgREST, mirroring the production
/// catalogue after PM-05 (read-only snapshot, 2026-10-24). The two deactivated
/// duplicates are included so filtering can be asserted.
const String soybeanDocId = 'f3c1b2a0-0000-5000-8000-000000000001';
// RB-PRODUCT-GRADE-01: product that only has the seeded Good / Average grades (live IDs).
const String maizeDdgsId = 'ba4cab5b-be26-5f61-9556-147d85bdc046';
const String maizeDdgsGoodId = '3589d5bd-9b88-5083-957b-9e643543b97a';
const String maizeDdgsAverageId = '70ba2b8c-cd87-594f-9ffa-14df9649e1d2';
const String distilleryCategoryId = 'd1571e00-0000-5000-8000-000000000001';
const String grainsCategoryId = 'a3b89ba6-fc77-4db6-ba32-25d833bf29ee';
const String oilseedsCategoryId = 'fe59c01d-228e-47a8-854a-e0803cdadfa4';
const String oilCakesCategoryId = 'a283c4bd-e07a-5a16-9fb5-af37c31b0310';

/// `master_categories` names after RB-PRODUCT-MASTER-07 (authenticated read, migration 0042).
const Map<String, String> productMasterCategories = {
  grainsCategoryId: 'Grains & Energy Ingredients',
  oilseedsCategoryId: 'Whole Oilseeds, Pulses & Other Agricultural Feed Commodities',
  oilCakesCategoryId: 'Oil Cakes & Oil Meals',
  distilleryCategoryId: 'Distillery & Fermentation By-products',
};

const List<Map<String, dynamic>> productMasterRows = [
  {'id': dalId, 'name': 'Dal', 'code': null, 'status': true, 'category_id': grainsCategoryId},
  {'id': riceId, 'name': 'Rice', 'code': null, 'status': true, 'category_id': grainsCategoryId},
  {'id': wheatId, 'name': 'Sharbati Wheat', 'code': 'WHEAT-01', 'status': true, 'category_id': grainsCategoryId},
  {'id': soybeanId, 'name': 'Soybean Seed', 'code': 'SOY-01', 'status': true, 'category_id': oilseedsCategoryId},
  {'id': maizeId, 'name': 'Yellow Maize (Corn)', 'code': 'MAIZE-01', 'status': true, 'category_id': grainsCategoryId},
  // New in PM-07: active, categorised, no grade policy yet.
  {'id': soybeanDocId, 'name': 'Soybean DOC', 'code': null, 'status': true, 'category_id': oilCakesCategoryId},
  {'id': maizeDdgsId, 'name': 'Maize DDGS', 'code': null, 'status': true, 'category_id': distilleryCategoryId},
  {'id': inactiveMaizeId, 'name': 'maize', 'code': null, 'status': false, 'category_id': grainsCategoryId},
  {'id': inactiveWheatId, 'name': 'Wheat', 'code': null, 'status': false, 'category_id': grainsCategoryId},
];

/// Live grade IDs per commodity (production snapshot).
const Map<String, List<MasterGrade>> productMasterGrades = {
  maizeId: [
    MasterGrade(id: '21000000-0000-0000-0000-000000000002', commodityId: maizeId, gradeName: 'Feed Grade Premium'),
    MasterGrade(id: '21000000-0000-0000-0000-000000000001', commodityId: maizeId, gradeName: 'Grade A Milling'),
  ],
  wheatId: [
    MasterGrade(id: '21000000-0000-0000-0000-000000000003', commodityId: wheatId, gradeName: 'Premium Sharbati'),
  ],
  soybeanId: [
    MasterGrade(id: '21000000-0000-0000-0000-000000000004', commodityId: soybeanId, gradeName: 'Standard Mandi Grade'),
  ],
  dalId: [
    MasterGrade(id: '1f13a047-687d-4f61-bc25-5f93f134ae10', commodityId: dalId, gradeName: 'Moisture'),
  ],
  maizeDdgsId: [
    MasterGrade(id: maizeDdgsAverageId, commodityId: maizeDdgsId, gradeName: 'Average'),
    MasterGrade(id: maizeDdgsGoodId, commodityId: maizeDdgsId, gradeName: 'Good'),
  ],
  riceId: [
    MasterGrade(id: 'eab13ce7-b2c6-4610-a83a-eee5bae300af', commodityId: riceId, gradeName: 'Moisture <12%'),
  ],
};

/// In-memory repository for widget tests: serves the catalogue snapshot, can be
/// switched into failure/empty modes, and records submitted requirements
/// instead of writing anywhere.
class FakeRequirementsRepository extends RequirementsRepository {
  List<Map<String, dynamic>> rows;
  Object? commodityError;
  Future<void>? commodityGate;
  int commodityLoads = 0;
  final List<CreateRequirementDto> submitted = [];

  FakeRequirementsRepository({
    List<Map<String, dynamic>>? rows,
    this.commodityError,
  }) : rows = rows ?? productMasterRows;

  @override
  Future<List<MasterCommodity>> getMasterCommodities() async {
    commodityLoads++;
    if (commodityGate != null) await commodityGate;
    if (commodityError != null) throw commodityError!;
    // Server-side `status = true` filter, then the repository's own parsing.
    final active = rows.where((r) => r['status'] == true).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return RequirementsRepository.parseActiveCommodities(active, categoryNames: productMasterCategories);
  }

  @override
  Future<List<MasterGrade>> getMasterGrades(String commodityId) async {
    return productMasterGrades[commodityId] ?? const [];
  }

  @override
  Future<BuyerRequirement> createRequirement(CreateRequirementDto dto) async {
    submitted.add(dto);
    return BuyerRequirement(
      id: 'REQ-TEST-${submitted.length}',
      commodityName: dto.commodityName,
      gradeName: dto.gradeName,
      quantity: dto.quantity,
      unit: dto.unitSymbol,
      targetPrice: dto.targetPrice,
      status: 'Open',
      targetDate: dto.targetDate,
      commodityId: dto.commodityId,
      gradeId: dto.gradeId,
      unitId: dto.unitId,
    );
  }
}
