import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Representation of a phone contact chosen by the user from the native system picker.
class PickedContact {
  final String name;
  final String phone;

  const PickedContact({required this.name, required this.phone});

  factory PickedContact.fromMap(Map<dynamic, dynamic> map) {
    return PickedContact(
      name: (map['name'] as String?)?.trim() ?? 'Selected Contact',
      phone: (map['phone'] as String?)?.trim() ?? '',
    );
  }
}

/// Result returned from the system contact picker.
class ContactPickerResult {
  final bool isSuccess;
  final bool isCancelled;
  final PickedContact? contact;
  final String? errorMessage;

  const ContactPickerResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.contact,
    this.errorMessage,
  });

  factory ContactPickerResult.success(PickedContact contact) {
    return ContactPickerResult._(
      isSuccess: true,
      isCancelled: false,
      contact: contact,
    );
  }

  factory ContactPickerResult.cancelled() {
    return const ContactPickerResult._(isSuccess: false, isCancelled: true);
  }

  factory ContactPickerResult.error(String message) {
    return ContactPickerResult._(
      isSuccess: false,
      isCancelled: false,
      errorMessage: message,
    );
  }
}

/// Service providing privacy-preserving contact selection via Android system picker.
/// Uses Intent.ACTION_PICK to return only the single contact chosen by the user,
/// without requesting broad address-book permissions or dumping contact lists.
class ContactPickerService {
  static const MethodChannel _channel = MethodChannel(
    'com.brokerbridge.rmseller/contacts',
  );

  const ContactPickerService();

  Future<ContactPickerResult> pickContact() async {
    try {
      final dynamic response = await _channel.invokeMethod('pickContact');
      if (response == null) {
        return ContactPickerResult.cancelled();
      }
      if (response is Map) {
        final contact = PickedContact.fromMap(response);
        if (contact.phone.isEmpty) {
          return ContactPickerResult.error(
            'The selected contact has no phone number attached. Please select another contact or add the number manually.',
          );
        }
        return ContactPickerResult.success(contact);
      }
      return ContactPickerResult.error(
        'Unexpected data returned by system contact picker.',
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED' || e.code == 'USER_CANCELLED') {
        return ContactPickerResult.cancelled();
      }
      debugPrint(
        'ContactPickerService PlatformException: ${e.code} - ${e.message}',
      );
      return ContactPickerResult.error(
        e.message ?? 'System contact picker failed.',
      );
    } catch (e) {
      debugPrint('ContactPickerService Exception: $e');
      return ContactPickerResult.error('Failed to open contacts: $e');
    }
  }
}
