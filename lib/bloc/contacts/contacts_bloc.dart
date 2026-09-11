import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'contacts_event.dart';
part 'contacts_state.dart';

/// Loads own-store members via GET /stores/:id/members.
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
       super(const ContactsState()) {
    on<ContactsStarted>(_onStarted);
    on<ContactsRefreshed>(_onRefreshed);
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
    emit(state.copyWith(isRefreshing: true, clearError: true));
    try {
      var storeId = _session.ownStoreId;
      var storeName = _session.profile?.ownStore?.name;
      if (storeId == null || storeId.isEmpty) {
        final profile = await _profileRepository.fetchMe();
        storeId = profile.ownStore?.id;
        storeName = profile.ownStore?.name;
      }
      if (storeId == null || storeId.isEmpty) {
        emit(
          state.copyWith(
            isRefreshing: false,
            members: const [],
            hasOwnStore: false,
            clearStore: true,
          ),
        );
        return;
      }
      final page = await _storeRepository.fetchMembers(
        storeId: storeId,
        limit: 100,
      );
      AppLog.d(_tag, 'Loaded ${page.items.length} members for $storeId');
      emit(
        state.copyWith(
          isRefreshing: false,
          members: page.items,
          storeId: storeId,
          storeName: storeName,
          hasOwnStore: true,
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

  void _onClearMessage(
    ContactsClearMessage event,
    Emitter<ContactsState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
