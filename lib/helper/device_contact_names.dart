import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/phone_normalize.dart';
import 'package:project_c/models/catalog/store_member_models.dart';

/// Quiet device-contact name lookup by E.164 phone.
///
/// Used when catalog members have null `firstName`/`lastName`. No UI loaders —
/// callers should enrich in the background after showing API data.
abstract final class DeviceContactNames {
  static const _tag = 'DeviceContactNames';

  static Map<String, String>? _cache;
  static Future<Map<String, String>>? _inFlight;

  /// E.164 → device display name. Cached for the app session.
  static Future<Map<String, String>> load({bool forceRefresh = false}) {
    if (!forceRefresh && _cache != null) {
      return Future<Map<String, String>>.value(_cache!);
    }
    if (!forceRefresh && _inFlight != null) return _inFlight!;
    _inFlight = _loadInternal();
    return _inFlight!;
  }

  static Future<Map<String, String>> _loadInternal() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        AppLog.d(_tag, 'Contacts permission denied');
        _cache = const {};
        return _cache!;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final map = <String, String>{};
      for (final contact in contacts) {
        final name = contact.displayName.trim();
        if (name.isEmpty) continue;
        for (final phone in contact.phones) {
          final e164 = PhoneNormalize.toE164(phone.number);
          if (e164 == null || map.containsKey(e164)) continue;
          map[e164] = name;
        }
      }
      AppLog.d(_tag, 'Indexed ${map.length} contact phones');
      _cache = map;
      return map;
    } catch (e) {
      AppLog.e(_tag, 'Failed to load device contacts', e);
      _cache = const {};
      return _cache!;
    } finally {
      _inFlight = null;
    }
  }

  /// API name → device contact name → phone.
  static String resolve({
    required String phone,
    String? firstName,
    String? lastName,
    Map<String, String> contactNames = const {},
  }) {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      if (last.isEmpty) return first;
      if (first.isEmpty) return last;
      return '$first $last';
    }
    final e164 = PhoneNormalize.toE164(phone) ?? phone.trim();
    final local = contactNames[e164]?.trim() ?? '';
    if (local.isNotEmpty) return local;
    return phone.trim().isEmpty ? 'Unknown' : phone.trim();
  }

  static Future<List<StoreMember>> enrichMembers(
    List<StoreMember> members,
  ) async {
    if (members.isEmpty) return members;
    final needsLookup = members.any((m) {
      final first = m.firstName?.trim() ?? '';
      final last = m.lastName?.trim() ?? '';
      return first.isEmpty && last.isEmpty;
    });
    if (!needsLookup) return members;

    final names = await load();
    if (names.isEmpty) return members;

    var changed = false;
    final next = <StoreMember>[];
    for (final m in members) {
      final first = m.firstName?.trim() ?? '';
      final last = m.lastName?.trim() ?? '';
      if (first.isNotEmpty || last.isNotEmpty) {
        next.add(m);
        continue;
      }
      final e164 = PhoneNormalize.toE164(m.phone) ?? m.phone.trim();
      final local = names[e164]?.trim() ?? '';
      if (local.isEmpty) {
        next.add(m);
        continue;
      }
      changed = true;
      next.add(m.copyWith(localName: local));
    }
    return changed ? next : members;
  }
}
