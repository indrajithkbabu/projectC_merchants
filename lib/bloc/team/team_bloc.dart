import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/safe_display_text.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'team_event.dart';
part 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc({
    StoreRepository? storeRepository,
    CatalogSession? session,
  }) : _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(const TeamState(isLoadingContacts: true)) {
    on<TeamContactsLoadRequested>(_onLoadContacts);
    on<TeamSearchChanged>(_onSearchChanged);
    on<TeamMemberToggled>(_onMemberToggled);
    on<TeamContinuePressed>(_onContinuePressed);
    on<TeamClearCompleted>(_onClearCompleted);
    on<TeamClearMessage>(_onClearMessage);
    add(const TeamContactsLoadRequested());
  }

  final StoreRepository _storeRepository;
  final CatalogSession _session;
  static const _tag = 'TeamBloc';

  static const _avatarPalette = <int>[
    0xFF2AABEE,
    0xFFE74C3C,
    0xFF3498DB,
    0xFF2ECC71,
    0xFFE67E22,
    0xFF9B59B6,
    0xFF1ABC9C,
    0xFFE91E63,
  ];

  Future<void> _onLoadContacts(
    TeamContactsLoadRequested event,
    Emitter<TeamState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingContacts: true,
        permissionDenied: false,
        clearError: true,
      ),
    );
    try {
      // Shared with listing / Contacts — never request permission twice.
      final result = await DeviceContactNames.loadContactList();
      if (result.permissionDenied) {
        AppLog.d(_tag, 'Contacts permission denied');
        emit(
          state.copyWith(
            isLoadingContacts: false,
            permissionDenied: true,
            allContacts: const [],
            searchResults: const [],
          ),
        );
        return;
      }

      final members = _mapDeviceContacts(result.contacts);
      AppLog.d(_tag, 'Loaded ${members.length} device contacts with phones');
      emit(
        state.copyWith(
          isLoadingContacts: false,
          permissionDenied: false,
          allContacts: members,
          searchResults: _filter(members, state.query),
          // Drop selections that no longer exist after reload.
          addedIds: state.addedIds.intersection(
            members.map((m) => m.id).toSet(),
          ),
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Contacts load failed', e);
      emit(
        state.copyWith(
          isLoadingContacts: false,
          allContacts: const [],
          searchResults: const [],
          errorMessage: 'Unable to load contacts right now.',
        ),
      );
    }
  }

  void _onSearchChanged(TeamSearchChanged event, Emitter<TeamState> emit) {
    emit(
      state.copyWith(
        query: event.query,
        searchResults: _filter(state.allContacts, event.query),
      ),
    );
  }

  void _onMemberToggled(TeamMemberToggled event, Emitter<TeamState> emit) {
    final added = Set<String>.from(state.addedIds);
    if (added.contains(event.memberId)) {
      added.remove(event.memberId);
    } else {
      added.add(event.memberId);
    }
    emit(state.copyWith(addedIds: added));
  }

  Future<void> _onContinuePressed(
    TeamContinuePressed event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final storeId = _session.ownStoreId;
    final phones =
        state.addedMembers
            .map((m) => m.phone)
            .where((p) => p.isNotEmpty)
            .toList();

    // Skip / empty selection: continue to home without failing.
    if (storeId == null || storeId.isEmpty || phones.isEmpty) {
      AppLog.d(_tag, 'Skipping contacts (no store or empty selection)');
      emit(state.copyWith(isSubmitting: false, isCompleted: true));
      return;
    }

    try {
      // Catalog allows max 30 phones per batch.
      for (var i = 0; i < phones.length; i += 30) {
        final end = (i + 30 < phones.length) ? i + 30 : phones.length;
        final batch = phones.sublist(i, end);
        await _storeRepository.addContacts(storeId: storeId, phones: batch);
      }
      AppLog.d(_tag, 'Contacts submitted count=${phones.length}');
      emit(state.copyWith(isSubmitting: false, isCompleted: true));
    } catch (e) {
      // Contact failure must not undo store creation — still allow home.
      AppLog.e(_tag, 'Contacts failed; continuing', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          isCompleted: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearCompleted(TeamClearCompleted event, Emitter<TeamState> emit) {
    emit(state.copyWith(clearCompleted: true));
  }

  void _onClearMessage(TeamClearMessage event, Emitter<TeamState> emit) {
    emit(state.copyWith(clearError: true));
  }

  List<TeamMember> _filter(List<TeamMember> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((m) {
      return m.name.toLowerCase().contains(q) ||
          m.phone.contains(q) ||
          m.handle.toLowerCase().contains(q);
    }).toList();
  }

  List<TeamMember> _mapDeviceContacts(
    List<({String phone, String name})> contacts,
  ) {
    return [
      for (var i = 0; i < contacts.length; i++)
        TeamMember(
          id: contacts[i].phone,
          name: contacts[i].name,
          handle: contacts[i].phone,
          phone: contacts[i].phone,
          avatarColor: _avatarPalette[i % _avatarPalette.length],
        ),
    ];
  }
}
