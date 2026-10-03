import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/network_status/network_status_cubit.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// PhonePe-style network strip + [AbsorbPointer] gate for all routes.
///
/// Wrap via [MaterialApp.builder] so every screen is covered without touching
/// individual routes or [ScreenWrapper].
///
/// When visible, the strip is laid out in a [Column] (not a [Stack] overlay)
/// so it **pushes** the whole navigator down — nothing is covered.
class NetworkStatusGate extends StatelessWidget {
  const NetworkStatusGate({super.key, required this.child});

  final Widget child;

  static const double _bannerBodyHeight = 28;

  static const SystemUiOverlayStyle _bannerOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Matches default light-chrome style used when the strip dismisses.
  static const SystemUiOverlayStyle _defaultOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.scaffold,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<NetworkStatusCubit, NetworkStatusState>(
      listenWhen: (prev, curr) => prev.banner != curr.banner,
      listener: (context, state) {
        // Route-level [ScreenWrapper] AnnotatedRegions sit deeper than this
        // builder, so force status-bar icon contrast while the strip is up.
        SystemChrome.setSystemUIOverlayStyle(
          state.showBanner ? _bannerOverlay : _defaultOverlay,
        );
      },
      child: BlocBuilder<NetworkStatusCubit, NetworkStatusState>(
        buildWhen:
            (prev, curr) =>
                prev.isOnline != curr.isOnline || prev.banner != curr.banner,
        builder: (context, state) {
          final offline = !state.isOnline;
          final showBanner = state.showBanner;
          final isRestored = state.banner == NetworkBannerKind.restored;
          final bannerColor =
              isRestored ? AppColors.success : AppColors.error;

          final media = MediaQuery.of(context);
          // Banner owns the top system inset while visible — clear it for
          // descendants so ScreenWrapper / headers do not double-pad.
          final childMedia =
              showBanner
                  ? media.copyWith(
                    padding: media.padding.copyWith(top: 0),
                    viewPadding: media.viewPadding.copyWith(top: 0),
                  )
                  : media;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBanner)
                Material(
                  color: bannerColor,
                  elevation: 0,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: _bannerBodyHeight,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          isRestored
                              ? 'Back online'
                              : 'No internet connection',
                          style: AppTextStyles.caption(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: MediaQuery(
                  data: childMedia,
                  child: AbsorbPointer(absorbing: offline, child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
