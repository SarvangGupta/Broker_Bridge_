import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/directory_repository.dart';
import '../../domain/directory_contact.dart';
import '../../domain/directory_state.dart';
import 'directory_controller.dart';

/// Controller managing a single contact's 360-degree profile.
class ContactDetailsController extends Notifier<ContactDetailsState> {
  final String contactId;

  ContactDetailsController(this.contactId);

  DirectoryRepository get _repository => ref.read(directoryRepositoryProvider);

  @override
  ContactDetailsState build() {
    Future.microtask(() => loadDetails());
    return const ContactDetailsState(status: ContactDetailsStatus.loading);
  }

  /// Load 360-degree details from backend.
  Future<void> loadDetails() async {
    state = state.copyWith(status: ContactDetailsStatus.loading);

    final result = await _repository.getContactDetails(contactId);

    switch (result) {
      case DirectorySuccess<ContactDetailsPayload>(:final data):
        state = state.copyWith(
          status: ContactDetailsStatus.loaded,
          payload: data,
          errorMessage: null,
        );

      case DirectoryUnavailable<ContactDetailsPayload>(:final contractNotice):
        state = state.copyWith(
          status: ContactDetailsStatus.error,
          errorMessage: contractNotice,
        );

      case DirectoryError<ContactDetailsPayload>(:final message):
        state = state.copyWith(
          status: ContactDetailsStatus.error,
          errorMessage: message,
        );

      case DirectoryUnauthorized<ContactDetailsPayload>(:final message):
        state = state.copyWith(
          status: ContactDetailsStatus.error,
          errorMessage: message,
        );
    }
  }

  /// Toggle Active / Inactive soft archival status.
  Future<bool> toggleStatus() async {
    if (state.payload == null) return false;

    state = state.copyWith(status: ContactDetailsStatus.togglingStatus);
    final result = await _repository.toggleContactStatus(contactId);

    if (result is DirectorySuccess<bool>) {
      final newStatus = result.data;
      final updatedContact = state.payload!.contact.copyWith(status: newStatus);
      final updatedPayload = ContactDetailsPayload(
        contact: updatedContact,
        associatedRequirements: state.payload!.associatedRequirements,
        associatedOffers: state.payload!.associatedOffers,
        linkedDeals: state.payload!.linkedDeals,
        activities: state.payload!.activities,
      );

      state = state.copyWith(
        status: ContactDetailsStatus.loaded,
        payload: updatedPayload,
      );

      // Update parent list controller
      ref.read(directoryControllerProvider.notifier).upsertContact(updatedContact);
      return true;
    } else {
      state = state.copyWith(
        status: ContactDetailsStatus.loaded,
        errorMessage: 'Failed to update contact status',
      );
      return false;
    }
  }
}

/// Family provider for ContactDetailsController keyed by contactId.
final contactDetailsControllerProvider =
    NotifierProvider.family<ContactDetailsController, ContactDetailsState, String>(
  (contactId) => ContactDetailsController(contactId),
);
