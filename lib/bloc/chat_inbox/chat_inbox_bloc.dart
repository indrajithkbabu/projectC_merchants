import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/chat/chat_repository.dart';

part 'chat_inbox_event.dart';
part 'chat_inbox_state.dart';

/// Message tab inbox for the active catalog profile.
///
/// Loads capabilities, then pages `view=inbox` until the cursor is exhausted.
class ChatInboxBloc extends Bloc<ChatInboxEvent, ChatInboxState> {
  ChatInboxBloc({ChatRepository? repository})
    : _repository = repository ?? ServiceLocator.get<ChatRepository>(),
      super(const ChatInboxState()) {
    on<ChatInboxProfileSelected>(_onProfileSelected);
    on<ChatInboxRefreshed>(_onRefreshed);
  }

  final ChatRepository _repository;
  Timer? _poll;
  static const _tag = 'ChatInboxBloc';
  static const _pageSize = 50;
  static const _maxPages = 40;

  int _ticket = 0;

  Future<void> _onProfileSelected(
    ChatInboxProfileSelected event,
    Emitter<ChatInboxState> emit,
  ) async {
    final profileId = event.profileId.trim();
    if (profileId.isNotEmpty &&
        profileId == state.profileId &&
        (state.isLoading || state.hasFetched)) {
      return;
    }
    await _load(
      emit,
      profileId: profileId,
      clearItems: profileId != state.profileId,
    );
  }

  Future<void> _onRefreshed(
    ChatInboxRefreshed event,
    Emitter<ChatInboxState> emit,
  ) async {
    await _load(emit, profileId: state.profileId, clearItems: false);
  }

  Future<void> _load(
    Emitter<ChatInboxState> emit, {
    required String profileId,
    required bool clearItems,
  }) async {
    final ticket = ++_ticket;
    final keepItems = clearItems ? const <ChatRelationship>[] : state.items;
    emit(
      state.copyWith(
        profileId: profileId,
        items: keepItems,
        isLoading: keepItems.isEmpty,
        isRefreshing: keepItems.isNotEmpty,
        isLoadingMore: false,
        unavailable: false,
        clearError: true,
        clearCursor: clearItems,
        hasFetched: clearItems ? false : state.hasFetched,
      ),
    );

    bool alive() => ticket == _ticket && !emit.isDone;

    try {
      final capabilities = await _repository.getCapabilities();
      if (!alive()) return;
      if (!capabilities.enabled) {
        _emitUnavailable(emit, capabilities);
        return;
      }

      final byId = <String, ChatRelationship>{};
      String? cursor;
      var pages = 0;
      while (pages < _maxPages) {
        pages++;
        final page = await _repository.listRelationships(
          view: ChatRelationshipView.inbox,
          limit: _pageSize,
          cursor: cursor,
        );
        if (!alive()) return;
        for (final item in page.items) {
          byId[item.id] = item;
        }
        final more = page.hasMore;
        cursor = more ? page.nextCursor : null;
        emit(
          state.copyWith(
            capabilities: capabilities,
            writesEnabled: capabilities.writesEnabled,
            unavailable: false,
            isLoading: false,
            isRefreshing: false,
            isLoadingMore: more,
            hasFetched: true,
            clearError: true,
            items: List<ChatRelationship>.unmodifiable(byId.values),
            nextCursor: cursor,
            clearCursor: !more,
          ),
        );
        if (!more) {
          _ensurePoll();
          return;
        }
      }
      if (!alive()) return;
      emit(state.copyWith(isLoadingMore: false));
    } on CatalogApiException catch (error) {
      if (!alive()) return;
      if (error.code == 'CHAT_DISABLED') {
        _emitUnavailable(emit, state.capabilities);
        return;
      }
      AppLog.d(_tag, 'inbox failed code=${error.code}');
      _emitFailure(emit, error);
    } catch (error) {
      if (!alive()) return;
      AppLog.d(_tag, 'inbox failed ${error.runtimeType}');
      _emitFailure(emit, error);
    }
  }

  void _ensurePoll() {
    _poll ??= Timer.periodic(const Duration(seconds: 8), (_) {
      if (isClosed || state.profileId.isEmpty) return;
      if (state.isLoading || state.isRefreshing || state.unavailable) return;
      if (state.capabilities?.enabled == false) return;
      add(const ChatInboxRefreshed());
    });
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }

  void _emitUnavailable(
    Emitter<ChatInboxState> emit,
    ChatCapabilities? capabilities,
  ) {
    emit(
      state.copyWith(
        capabilities: capabilities,
        writesEnabled: false,
        unavailable: true,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        hasFetched: true,
        items: const [],
        clearCursor: true,
        clearError: true,
      ),
    );
  }

  void _emitFailure(Emitter<ChatInboxState> emit, Object error) {
    emit(
      state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        hasFetched: true,
        errorMessage: CatalogErrorMapper.toUserMessage(error),
      ),
    );
  }
}
