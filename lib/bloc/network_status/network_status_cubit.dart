import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:project_c/helper/app_log.dart';

part 'network_status_state.dart';

/// App-wide Wi‑Fi / mobile connectivity (PhonePe-style top strip).
///
/// Uses [connectivity_plus] transport detection — not a DNS probe.
/// Call [start] once at app launch; [recheck] on resume (Android O+).
class NetworkStatusCubit extends Cubit<NetworkStatusState>
    with WidgetsBindingObserver {
  NetworkStatusCubit({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity(),
      super(const NetworkStatusState());

  static const _tag = 'NetworkStatus';
  static const _restoredVisible = Duration(seconds: 2);

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _restoredTimer;
  bool _started = false;
  bool _wasOffline = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      final initial = await _connectivity.checkConnectivity();
      _applyResults(initial, fromInitial: true);
    } catch (e) {
      AppLog.e(_tag, 'Initial connectivity check failed', e);
      emit(state.copyWith(hasResolvedInitial: true));
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => _applyResults(results),
      onError: (Object e, StackTrace st) {
        AppLog.e(_tag, 'Connectivity stream error', e);
      },
    );
  }

  /// Re-check after app resume (Android may miss background broadcasts).
  Future<void> recheck() async {
    if (!_started) return;
    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (e) {
      AppLog.e(_tag, 'Resume connectivity check failed', e);
    }
  }

  void dismissRestoredBanner() {
    if (state.banner != NetworkBannerKind.restored) return;
    _restoredTimer?.cancel();
    emit(state.copyWith(banner: NetworkBannerKind.hidden));
  }

  void _applyResults(
    List<ConnectivityResult> results, {
    bool fromInitial = false,
  }) {
    final online = _hasNetwork(results);
    AppLog.d(
      _tag,
      'connectivity=${results.map((e) => e.name).join(",")} online=$online',
    );

    if (!online) {
      _restoredTimer?.cancel();
      _wasOffline = true;
      emit(
        state.copyWith(
          isOnline: false,
          banner: NetworkBannerKind.offline,
          hasResolvedInitial: true,
        ),
      );
      return;
    }

    // Online.
    final comingBack = _wasOffline || state.banner == NetworkBannerKind.offline;
    _wasOffline = false;

    if (comingBack && !fromInitial) {
      emit(
        state.copyWith(
          isOnline: true,
          banner: NetworkBannerKind.restored,
          hasResolvedInitial: true,
        ),
      );
      _scheduleRestoredHide();
      return;
    }

    emit(
      state.copyWith(
        isOnline: true,
        banner: NetworkBannerKind.hidden,
        hasResolvedInitial: true,
      ),
    );
  }

  void _scheduleRestoredHide() {
    _restoredTimer?.cancel();
    _restoredTimer = Timer(_restoredVisible, () {
      if (isClosed) return;
      if (state.banner == NetworkBannerKind.restored) {
        emit(state.copyWith(banner: NetworkBannerKind.hidden));
      }
    });
  }

  static bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      recheck();
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    _restoredTimer?.cancel();
    return super.close();
  }
}
