import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';

/// Profile repository with a controllable saved location (null = none saved)
/// and server readiness result.
class FakeProfileRepository extends SellerProfileRepository {
  BusinessLocationModel? savedLocation;
  final String? savedOffice;
  ListingReadiness readiness;
  final List<BusinessLocationModel> savedWarehousesList = [];

  /// Locations saved as the device default via the posting flow.
  final List<BusinessLocationModel> savedDefaults = [];

  FakeProfileRepository({
    this.savedLocation,
    this.savedOffice,
    this.readiness = const ListingReadiness.complete(firmName: 'Test Agro Firm'),
    List<BusinessLocationModel>? warehouses,
  }) {
    if (warehouses != null) {
      savedWarehousesList.addAll(warehouses);
    } else if (savedLocation != null) {
      savedWarehousesList.add(savedLocation!);
    }
  }

  @override
  Future<ListingReadiness> checkListingReadiness() async => readiness;

  @override
  Future<void> saveBusinessLocationDefault(
    BusinessLocationModel loc, {
    bool isUpdate = false,
    String? userId,
  }) async {
    savedDefaults.add(loc);
    savedLocation = loc;
    if (!savedWarehousesList.any((w) => w.name == loc.name && w.addressLine == loc.addressLine)) {
      savedWarehousesList.add(loc);
    }
  }

  /// A saved warehouse that maps onto the offline state/district masters.
  factory FakeProfileRepository.withWarehouse({
    String? office,
    ListingReadiness readiness = const ListingReadiness.complete(
      firmName: 'Test Agro Firm',
    ),
  }) {
    final state = MasterCommodityData.verifiedStates.first;
    final district = MasterCommodityData.verifiedDistricts.firstWhere(
      (d) => d.stateId == state.id,
    );
    return FakeProfileRepository(
      savedLocation: BusinessLocationModel(
        name: 'Test Godown',
        addressLine: 'Plot 7, Test Road',
        locality: '',
        stateId: state.id,
        stateName: state.name,
        districtId: district.id,
        districtName: district.name,
        pinCode: '111111',
        latitude: null,
        longitude: null,
      ),
      savedOffice: office,
      readiness: readiness,
    );
  }

  @override
  Future<BusinessLocationModel?> getSavedBusinessLocation({String? userId}) async =>
      savedLocation;

  @override
  Future<List<BusinessLocationModel>> getSavedWarehouses({String? userId}) async =>
      savedWarehousesList.isNotEmpty
          ? savedWarehousesList
          : (savedLocation != null ? [savedLocation!] : const []);

  @override
  Future<void> saveWarehouse(
    BusinessLocationModel loc, {
    bool setAsDefault = true,
    String? userId,
  }) async {
    savedWarehousesList.add(loc);
    if (setAsDefault) savedLocation = loc;
  }

  @override
  Future<String?> getSavedOfficeAddress() async => savedOffice;
}

/// Taps "Review & List Commodity" and, when the review opens, confirms with
/// "List Commodity on Desk" (RB-SELLER-POST-UX-05 two-step listing).
Future<void> listViaReview(WidgetTester tester) async {
  final review = find.byKey(const Key('review_and_list_button'));
  await tester.ensureVisible(review);
  await tester.tap(review);
  await tester.pumpAndSettle();
  final confirm = find.byKey(const Key('confirm_list_button'));
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}
