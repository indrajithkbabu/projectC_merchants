part of 'network_status_cubit.dart';

/// Visual phase of the PhonePe-style network strip.
enum NetworkBannerKind {
  /// No strip (online, or green restore already dismissed).
  hidden,

  /// Red — no Wi‑Fi / mobile network.
  offline,

  /// Green — connection just restored (auto-hides).
  restored,
}

final class NetworkStatusState extends Equatable {
  const NetworkStatusState({
    this.isOnline = true,
    this.banner = NetworkBannerKind.hidden,
    this.hasResolvedInitial = false,
  });

  /// `true` when at least one transport (Wi‑Fi, mobile, ethernet, etc.) is up.
  final bool isOnline;

  final NetworkBannerKind banner;

  /// `false` until the first [Connectivity.checkConnectivity] completes.
  final bool hasResolvedInitial;

  bool get showBanner => banner != NetworkBannerKind.hidden;

  NetworkStatusState copyWith({
    bool? isOnline,
    NetworkBannerKind? banner,
    bool? hasResolvedInitial,
  }) {
    return NetworkStatusState(
      isOnline: isOnline ?? this.isOnline,
      banner: banner ?? this.banner,
      hasResolvedInitial: hasResolvedInitial ?? this.hasResolvedInitial,
    );
  }

  @override
  List<Object?> get props => [isOnline, banner, hasResolvedInitial];
}
