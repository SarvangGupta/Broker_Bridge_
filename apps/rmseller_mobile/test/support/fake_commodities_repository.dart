import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';

// RB-PRODUCT-MASTER-07: IDs and category names as in the live Product Master.
const soybeanDocId = 'aa000000-0000-0000-0000-000000000001';
const maizeId = '20000000-0000-0000-0000-000000000001';
const wheatBranId = '8f58c547-e988-5843-954a-6e0e57ae6b44';
const uncategorisedId = 'aa000000-0000-0000-0000-000000000009';
const maizeGradeAId = '21000000-0000-0000-0000-000000000001';
const maizeFeedId = '21000000-0000-0000-0000-000000000002';
const wheatBranFaqId = '5dcb586c-632a-50c0-b097-a33efae04a20';
// RB-PRODUCT-GRADE-01: product that only has the seeded Good / Average grades (live IDs).
const maizeDdgsId = 'ba4cab5b-be26-5f61-9556-147d85bdc046';
const maizeDdgsGoodId = '3589d5bd-9b88-5083-957b-9e643543b97a';
const maizeDdgsAverageId = '70ba2b8c-cd87-594f-9ffa-14df9649e1d2';

const liveCatalogue = [
  MasterCommodity(id: soybeanDocId, name: 'Soybean DOC', code: '', categoryName: 'Oil Cakes & Oil Meals'),
  MasterCommodity(id: uncategorisedId, name: 'Uncategorised Product', code: ''),
  MasterCommodity(id: wheatBranId, name: 'Wheat Bran', code: '', categoryName: 'Bran, Polish & Milling By-products'),
  MasterCommodity(id: maizeDdgsId, name: 'Maize DDGS', code: '', categoryName: 'Distillery & Fermentation By-products'),
  MasterCommodity(id: maizeId, name: 'Yellow Maize (Corn)', code: 'MAIZE-01', categoryName: 'Grains & Energy Ingredients'),
];

const liveGrades = {
  maizeId: [
    MasterGrade(id: maizeFeedId, commodityId: maizeId, gradeName: 'Feed Grade Premium'),
    MasterGrade(id: maizeGradeAId, commodityId: maizeId, gradeName: 'Grade A Milling'),
  ],
  maizeDdgsId: [
    MasterGrade(id: maizeDdgsAverageId, commodityId: maizeDdgsId, gradeName: 'Average'),
    MasterGrade(id: maizeDdgsGoodId, commodityId: maizeDdgsId, gradeName: 'Good'),
  ],
  wheatBranId: [
    MasterGrade(id: wheatBranFaqId, commodityId: wheatBranId, gradeName: 'FAQ (Fair Average Quality)'),
  ],
};

/// In-memory repository: serves the catalogue snapshot and records submitted lots
/// without writing anywhere (the submit throws after capturing the DTO).
class FakeCommoditiesRepository extends CommoditiesRepository {
  List<MasterCommodity> commodities;
  Object? commodityError;
  int commodityLoads = 0;
  final List<CreateCommodityDto> submitted = [];

  FakeCommoditiesRepository({List<MasterCommodity>? commodities, this.commodityError})
      : commodities = commodities ?? liveCatalogue,
        super(storage: SecureStorageService()..enableMemoryFallbackForTesting());

  @override
  Future<List<MasterCommodity>> getMasterCommodities() async {
    commodityLoads++;
    if (commodityError != null) throw commodityError!;
    return commodities;
  }

  @override
  Future<List<MasterGrade>> getMasterGrades(String commodityId) async =>
      liveGrades[commodityId] ?? const [];

  /// Server posting history; null = offline (no history source).
  List<SellerCommodity>? history;

  /// Thrown by [getPostingHistory] when set (a failed server read).
  Object? historyError;

  @override
  bool get isOnline => history != null || historyError != null;

  @override
  Future<List<SellerCommodity>> getPostingHistory() async {
    if (historyError != null) throw historyError!;
    return history ?? const [];
  }

  /// What the submit throws after capturing the DTO.
  Object submitError = Exception('captured by test (not persisted)');

  @override
  Future<SellerCommodity> createCommodity(CreateCommodityDto dto) async {
    submitted.add(dto);
    throw submitError;
  }
}
