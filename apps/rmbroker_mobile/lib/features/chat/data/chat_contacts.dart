import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatContactsRepositoryProvider = Provider<ChatContactsRepository>((ref) => ChatContactsRepository());

/// A buyer or seller the broker may chat with (name only; never phone/email).
class ChatContact {
  final String userId;
  final String name;
  final String role;
  final String? company;

  const ChatContact({required this.userId, required this.name, required this.role, this.company});

  factory ChatContact.fromMap(Map<String, dynamic> m) => ChatContact(
        userId: m['user_id'].toString(),
        name: (m['name']?.toString().trim().isNotEmpty ?? false) ? m['name'].toString() : 'Contact',
        role: m['role']?.toString() ?? '',
        company: m['company']?.toString(),
      );
}

/// Resolves the chat counterpart for a desk context through
/// `chat_contacts_for_context` (proposed 0066): the buyer of a requirement
/// assigned to this broker, or the seller of a lot this broker manages.
class ChatContactsRepository {
  final SupabaseClient? _customClient;

  ChatContactsRepository({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _db => _customClient ?? Supabase.instance.client;

  Future<List<ChatContact>> forContext({String? requirementId, String? availabilityId}) async {
    final rows = await _db.rpc(
      'chat_contacts_for_context',
      params: {'p_requirement_id': requirementId, 'p_availability_id': availabilityId},
    );
    return [
      for (final r in rows as List) ChatContact.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }
}

/// Explicit Chat action on a requirement (buyer) or a seller lot (seller):
/// resolves the counterpart and opens the conversation with them.
Future<void> openChatForContext(
  BuildContext context, {
  String? requirementId,
  String? availabilityId,
  ChatContactsRepository? repository,
}) async {
  final who = requirementId != null ? 'buyer' : 'seller';
  final messenger = ScaffoldMessenger.of(context);
  List<ChatContact> contacts;
  try {
    contacts = await (repository ?? ChatContactsRepository())
        .forContext(requirementId: requirementId, availabilityId: availabilityId);
  } catch (_) {
    messenger.showSnackBar(SnackBar(
      content: Text('Chat with this $who is not available right now. Check your connection and try again.'),
    ));
    return;
  }
  if (!context.mounted) return;
  if (contacts.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text('No $who account on this ${requirementId != null ? 'requirement' : 'lot'} can receive chat yet.'),
    ));
    return;
  }
  // One account per firm today; the first by name is used when several exist.
  final c = contacts.first;
  // The conversation is linked to this requirement / offer (0067), so the
  // buyer chat and the seller chat stay separate threads.
  final query = requirementId != null ? 'requirementId=$requirementId' : 'availabilityId=$availabilityId';
  await context.push('/chats/user/${c.userId}?$query', extra: c);
}
