import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_draft_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';

void main() {
  group('GstDraftRepository and GstDraft Unit Tests', () {
    late InMemoryGstDraftStorage storage;
    late GstDraftRepository repo;

    setUp(() {
      storage = InMemoryGstDraftStorage();
      repo = GstDraftRepository(storage: storage);
    });

    test('saves and loads a draft correctly', () async {
      final now = DateTime.now();
      final draft = GstDraft(
        companyId: 'company-123',
        userId: 'user-456',
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Acme Agro Ltd',
          GstField.validityFrom: '01/07/2017',
          GstField.pinCode: '302001',
        },
        imagePath: '/tmp/cert.png',
        savedAt: now,
        editedFields: {GstField.legalName},
      );

      await repo.saveDraft(draft);

      final hasDraft = await repo.hasDraft(companyId: 'company-123', userId: 'user-456');
      expect(hasDraft, isTrue);

      final loaded = await repo.getDraft(companyId: 'company-123', userId: 'user-456');
      expect(loaded, isNotNull);
      expect(loaded!.companyId, 'company-123');
      expect(loaded.userId, 'user-456');
      expect(loaded.values[GstField.gstin], '08AAAAA0000A1Z5');
      expect(loaded.values[GstField.legalName], 'Acme Agro Ltd');
      expect(loaded.values[GstField.validityFrom], '01/07/2017');
      expect(loaded.imagePath, '/tmp/cert.png');
      expect(loaded.editedFields.contains(GstField.legalName), isTrue);
    });

    test('isolates drafts by company and user', () async {
      final draft = GstDraft(
        companyId: 'company-A',
        userId: 'user-1',
        values: {GstField.gstin: '08AAAAA0000A1Z5'},
        savedAt: DateTime.now(),
      );
      await repo.saveDraft(draft);

      // Same user, different company
      expect(await repo.hasDraft(companyId: 'company-B', userId: 'user-1'), isFalse);
      expect(await repo.getDraft(companyId: 'company-B', userId: 'user-1'), isNull);

      // Different user, same company
      expect(await repo.hasDraft(companyId: 'company-A', userId: 'user-2'), isFalse);
      expect(await repo.getDraft(companyId: 'company-A', userId: 'user-2'), isNull);
    });

    test('clears draft upon request or submission', () async {
      final draft = GstDraft(
        companyId: 'company-123',
        userId: 'user-456',
        values: {GstField.gstin: '08AAAAA0000A1Z5'},
        savedAt: DateTime.now(),
      );
      await repo.saveDraft(draft);
      expect(await repo.hasDraft(companyId: 'company-123', userId: 'user-456'), isTrue);

      await repo.clearDraft(companyId: 'company-123', userId: 'user-456');
      expect(await repo.hasDraft(companyId: 'company-123', userId: 'user-456'), isFalse);
      expect(await repo.getDraft(companyId: 'company-123', userId: 'user-456'), isNull);
    });

    test('returns null for empty identifiers', () async {
      expect(await repo.getDraft(companyId: '', userId: 'user-1'), isNull);
      expect(await repo.getDraft(companyId: 'comp-1', userId: ''), isNull);
    });
  });
}

