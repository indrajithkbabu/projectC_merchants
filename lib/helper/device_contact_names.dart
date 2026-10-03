import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/phone_normalize.dart';
import 'package:project_c/helper/safe_display_text.dart';
import 'package:project_c/models/catalog/store_member_models.dart';

/// Quiet device-contact name lookup by phone.
///
/// Single shared permission + index for the whole app (listing, Contacts tab,
/// team picker, member enrich). Callers must not call
/// [FlutterContacts.requestPermission] themselves — that races on Android
/// ("Can request only one set of permissions at a time") and can hang forever.
abstract final class DeviceContactNames {
  static const _tag = 'DeviceContactNames';

  /// E.164 → display name.
  static Map<String, String>? _cache;

  /// Last-10 national digits → display name (unambiguous only).
  static Map<String, String>? _byNational;

  static Future<Map<String, String>>? _inFlight;
  static bool _permissionDenied = false;

  /// True once [load] has finished (granted or denied).
  static bool get isReady => _cache != null;

  static bool get permissionDenied => _permissionDenied;

  /// Fire-and-forget warm (safe to call repeatedly).
  static void prefetch() {
    // ignore: unawaited_futures
    load();
  }

  /// E.164 → device display name. Cached for the app session.
  static Future<Map<String, String>> load({bool forceRefresh = false}) {
    if (!forceRefresh && _cache != null) {
      return Future<Map<String, String>>.value(_cache!);
    }
    if (!forceRefresh && _inFlight != null) return _inFlight!;
    _inFlight = _loadInternal();
    return _inFlight!;
  }

  /// Phone/name pairs for invite / team pickers (same index as [load]).
  static Future<
    ({List<({String phone, String name})> contacts, bool permissionDenied})
  >
  loadContactList({bool forceRefresh = false}) async {
    final names = await load(forceRefresh: forceRefresh);
    if (_permissionDenied) {
      return (
        contacts: <({String phone, String name})>[],
        permissionDenied: true,
      );
    }
    final list =
        names.entries
            .map(
              (e) => (
                phone: e.key,
                name: e.value.isNotEmpty ? e.value : e.key,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return (contacts: list, permissionDenied: false);
  }

  /// Drop session cache (logout).
  static void invalidate() {
    _cache = null;
    _byNational = null;
    _inFlight = null;
    _permissionDenied = false;
  }

  /// Best device-contact name for [phone], or null when unmatched.
  ///
  /// Tries E.164 exact match, then unambiguous last-10 national match.
  static String? lookup(String phone) {
    final cache = _cache;
    if (cache == null || cache.isEmpty) return null;

    final e164 = PhoneNormalize.toE164(phone);
    if (e164 != null) {
      final hit = cache[e164]?.trim() ?? '';
      if (hit.isNotEmpty) return hit;
    }

    final trimmed = phone.trim();
    if (trimmed.isNotEmpty) {
      final hit = cache[trimmed]?.trim() ?? '';
      if (hit.isNotEmpty) return hit;
    }

    final national = _byNational;
    if (national == null || national.isEmpty) return null;
    final key = PhoneNormalize.nationalKey(e164 ?? phone);
    if (key == null) return null;
    final hit = national[key]?.trim() ?? '';
    return hit.isEmpty ? null : hit;
  }

  static Future<Map<String, String>> _loadInternal() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        AppLog.d(_tag, 'Contacts permission denied');
        _permissionDenied = true;
        _cache = const {};
        _byNational = const {};
        return _cache!;
      }
      _permissionDenied = false;
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final byE164 = <String, String>{};
      final byNational = <String, String>{};
      final ambiguousNational = <String>{};

      for (final contact in contacts) {
        final name = _bestDisplayName(contact);
        if (name.isEmpty) continue;
        for (final phone in contact.phones) {
          _indexPhone(
            raw: phone.number,
            name: name,
            byE164: byE164,
            byNational: byNational,
            ambiguousNational: ambiguousNational,
          );
          // Android often has a more reliable E.164 in normalizedNumber.
          final normalized = phone.normalizedNumber.trim();
          if (normalized.isNotEmpty && normalized != phone.number.trim()) {
            _indexPhone(
              raw: normalized,
              name: name,
              byE164: byE164,
              byNational: byNational,
              ambiguousNational: ambiguousNational,
            );
          }
        }
      }
      AppLog.d(
        _tag,
        'Indexed ${byE164.length} E.164 / ${byNational.length} national keys',
      );
      _cache = byE164;
      _byNational = byNational;
      return byE164;
    } catch (e) {
      AppLog.e(_tag, 'Failed to load device contacts', e);
      _permissionDenied = true;
      _cache = const {};
      _byNational = const {};
      return _cache!;
    } finally {
      _inFlight = null;
    }
  }

  static void _indexPhone({
    required String raw,
    required String name,
    required Map<String, String> byE164,
    required Map<String, String> byNational,
    required Set<String> ambiguousNational,
  }) {
    final e164 = PhoneNormalize.toE164(raw);
    if (e164 == null) return;
    byE164.putIfAbsent(e164, () => name);

    final key = PhoneNormalize.nationalKey(e164);
    if (key == null || ambiguousNational.contains(key)) return;
    final existing = byNational[key];
    if (existing == null) {
      byNational[key] = name;
    } else if (existing != name) {
      ambiguousNational.add(key);
      byNational.remove(key);
    }
  }

  static String _bestDisplayName(Contact contact) {
    final display = SafeDisplayText.sanitize(contact.displayName.trim());
    if (display.isNotEmpty) return display;

    final first = contact.name.first.trim();
    final middle = contact.name.middle.trim();
    final last = contact.name.last.trim();
    final parts = <String>[
      if (first.isNotEmpty) first,
      if (middle.isNotEmpty) middle,
      if (last.isNotEmpty) last,
    ];
    if (parts.isEmpty) return '';
    return SafeDisplayText.sanitize(parts.join(' '));
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
    final fromLookup = lookup(phone)?.trim() ?? '';
    if (fromLookup.isNotEmpty) return fromLookup;

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

    await load();
    if ((_cache ?? const {}).isEmpty && (_byNational ?? const {}).isEmpty) {
      return members;
    }

    var changed = false;
    final next = <StoreMember>[];
    for (final m in members) {
      final first = m.firstName?.trim() ?? '';
      final last = m.lastName?.trim() ?? '';
      if (first.isNotEmpty || last.isNotEmpty) {
        next.add(m);
        continue;
      }
      final local = lookup(m.phone)?.trim() ?? '';
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
