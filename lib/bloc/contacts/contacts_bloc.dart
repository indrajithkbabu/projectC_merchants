import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/phone_normalize.dart';
import 'package:project_c/helper/safe_display_text.dart';
import 'package:project_c/helper/whatsapp_invite.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'contacts_event.dart';
part 'contacts_state.dart';

/// Team roster + device invites. “With stores” is rendered from the existing
/// [StoreListingBloc] `/home` cache (no second home fetch). Peer stores and
/// device Invite list are available before the viewer creates their own store;
/// Your team requires an own store.
class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  ContactsBloc({
    StoreRepository? storeRepository,
    ProfileRepository? profileRepository,
    CatalogSession? session,
  }) : _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         () {
           final s = session ?? ServiceLocator.get<CatalogSession>();
           final ownId = s.ownStoreId?.trim() ?? '';
           final hasStore = ownId.isNotEmpty;
           return ContactsState(
             // Seed from session; peer stores still come from StoreListingBloc.
             hasOwnStore: hasStore,
             storeId: hasStore ? ownId : null,
             storeName: hasStore ? s.profile?.ownStore?.name : null,
             storeLink: hasStore ? s.profile?.ownStore?.storeLink : null,
           );
         }(),
       ) {
    on<ContactsStarted>(_onStarted);
    on<ContactsRefreshed>(_onRefreshed);
    on<ContactsInvitePressed>(_onInvitePressed);
    on<ContactsClearMessage>(_onClearMessage);
    add(const ContactsStarted());
  }

  final StoreRepository _storeRepository;
  final ProfileRepository _profileRepository;
  final CatalogSession _session;
  static const _tag = 'ContactsBloc';

  Future<void> _onStarted(
    ContactsStarted event,
    Emitter<ContactsState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _onRefreshed(
    ContactsRefreshed event,
    Emitter<ContactsState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _load(Emitter<ContactsState> emit) async {
    // Prefer session snapshot so own-store team section gates immediately.
    final sessionHasStore = _session.ownStoreId?.trim().isNotEmpty == true;
    emit(
      state.copyWith(
        isRefreshing: true,
        clearError: true,
        hasOwnStore: sessionHasStore,
        storeId: sessionHasStore ? _session.ownStoreId : null,
        storeName: sessionHasStore ? _session.profile?.ownStore?.name : null,
        storeLink: sessionHasStore ? _session.profile?.ownStore?.storeLink : null,
        clearStore: !sessionHasStore,
      ),
    );
    try {
      var storeId = _session.ownStoreId;
      var storeName = _session.profile?.ownStore?.name;
      var storeLink = _session.profile?.ownStore?.storeLink;
      if (storeId == null || storeId.isEmpty) {
        final profile = await _profileRepository.fetchMe();
        storeId = profile.ownStore?.id;
        storeName = profile.ownStore?.name;
        storeLink = profile.ownStore?.storeLink;
      }

      final id = (storeId ?? '').trim();
      final hasStore = id.isNotEmpty;
      final membersFuture =
          hasStore
              ? _storeRepository.fetchMembers(storeId: id, limit: 100)
              : null;
      final deviceFuture = _loadDeviceContacts();

      final page = membersFuture == null ? null : await membersFuture;
      final device = await deviceFuture;
      if (emit.isDone) return;

      if (page != null) {
        AppLog.d(_tag, 'Loaded ${page.items.length} members for $id');
      }

      final sortedMembers =
          page == null ? const <StoreMember>[] : _sortByName(page.items);
      final enriched =
          sortedMembers.isEmpty
              ? sortedMembers
              : await DeviceContactNames.enrichMembers(sortedMembers);
      if (emit.isDone) return;

      final rebuilt = _buildLists(
        members: enriched,
        deviceContacts: device.contacts,
        permissionDenied: device.permissionDenied,
        selfPhone: _session.profile?.phone,
      );
      emit(
        state.copyWith(
          isRefreshing: false,
          members: rebuilt.members,
          teamMembers: rebuilt.teamMembers,
          deviceContacts: rebuilt.deviceInvites,
          storeId: hasStore ? id : null,
          storeName: hasStore ? storeName : null,
          storeLink: hasStore ? storeLink : null,
          hasOwnStore: hasStore,
          permissionDenied: device.permissionDenied,
          clearStore: !hasStore,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Contacts load failed', e);
      emit(
        state.copyWith(
          isRefreshing: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onInvitePressed(
    ContactsInvitePressed event,
    Emitter<ContactsState> emit,
  ) async {
    final phone = event.phone.trim();
    if (phone.isEmpty || state.invitingPhone != null) return;

    emit(state.copyWith(invitingPhone: phone, clearError: true));
    final storeId = state.storeId;
    if (storeId != null && storeId.isNotEmpty) {
      try {
        await _storeRepository.addContacts(
          storeId: storeId,
          phones: [phone],
        );
        AppLog.d(_tag, 'Added invite contact $phone');
      } catch (e) {
        AppLog.e(_tag, 'addContacts failed; continuing to WhatsApp', e);
      }
    }

    final message = WhatsAppInvite.appInviteMessage(
      storeLink: state.storeLink,
    );

    final opened = await WhatsAppInvite.open(
      phoneE164: phone,
      message: message,
    );
    if (!opened) {
      emit(
        state.copyWith(
          clearInviting: true,
          errorMessage:
              'Could not open WhatsApp. Share the invite from the sheet, or install WhatsApp.',
        ),
      );
      // Still refresh so the contact moves into Your team after addContacts.
      await _load(emit);
      return;
    }

    emit(state.copyWith(clearInviting: true));
    await _load(emit);
  }

  void _onClearMessage(
    ContactsClearMessage event,
    Emitter<ContactsState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  List<StoreMember> _sortByName(List<StoreMember> members) {
    final next = List<StoreMember>.from(members);
    next.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return next;
  }

  ({
    List<StoreMember> members,
    List<StoreMember> teamMembers,
    List<ContactInviteCandidate> deviceInvites,
  })
  _buildLists({
    required List<StoreMember> members,
    required List<({String phone, String name})> deviceContacts,
    required bool permissionDenied,
    required String? selfPhone,
  }) {
    final selfE164 =
        PhoneNormalize.toE164(selfPhone ?? '') ?? selfPhone?.trim();

    final teamMembers = <StoreMember>[];
    final rosterPhones = <String>{};

    for (final m in members) {
      final e164 = PhoneNormalize.toE164(m.phone) ?? m.phone.trim();
      if (selfE164 != null && selfE164.isNotEmpty && e164 == selfE164) {
        continue;
      }
      rosterPhones.add(e164);
      teamMembers.add(m);
    }

    final deviceInvites = <ContactInviteCandidate>[];
    if (!permissionDenied) {
      for (final c in deviceContacts) {
        if (rosterPhones.contains(c.phone)) continue;
        if (selfE164 != null && selfE164.isNotEmpty && c.phone == selfE164) {
          continue;
        }
        deviceInvites.add(
          ContactInviteCandidate(
            phone: c.phone,
            name: SafeDisplayText.sanitize(c.name),
          ),
        );
      }
    }

    deviceInvites.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return (
      members: members,
      teamMembers: _sortByName(teamMembers),
      deviceInvites: deviceInvites,
    );
  }

  Future<
    ({
      List<({String phone, String name})> contacts,
      bool permissionDenied,
    })
  >
  _loadDeviceContacts() async {
    // Shared with StoreListingBloc — never request permission twice.
    final result = await DeviceContactNames.loadContactList();
    if (!result.permissionDenied) {
      AppLog.d(_tag, 'Device contacts with phones: ${result.contacts.length}');
    } else {
      AppLog.d(_tag, 'Contacts permission denied');
    }
    return result;
  }
}
