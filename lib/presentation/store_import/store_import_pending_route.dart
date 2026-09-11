import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_import/store_import_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/store_import/store_import_approved_route.dart';
import 'package:project_c/presentation/store_import/store_import_navigation.dart';

class StoreImportPendingRoute extends StatelessWidget {
  const StoreImportPendingRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreImportBloc, StoreImportState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreImportBloc>().add(
              const StoreImportClearMessage(),
            );
          },
        ),
        BlocListener<StoreImportBloc, StoreImportState>(
          listenWhen: (prev, curr) => curr.isApproved && !prev.isApproved,
          listener: (context, state) {
            final bloc = context.read<StoreImportBloc>();
            context.read<StoreImportBloc>().add(const StoreImportClearApproved());
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                settings: const RouteSettings(
                  name: Routes.storeImportApprovedRoute,
                ),
                builder:
                    (_) => BlocProvider.value(
                      value: bloc,
                      child: const StoreImportApprovedRoute(),
                    ),
              ),
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<StoreImportBloc, StoreImportState>(
          builder: (context, state) {
            final storeName = state.sourceStore.name;
            final count = state.selectedCount;
            return Padding(
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context),
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 34,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Request sent',
                          style: AppTextStyles.title(fontSize: 28),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.bodySecondary(),
                            children: [
                              const TextSpan(text: 'Waiting for '),
                              TextSpan(
                                text: storeName,
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' to approve importing '),
                              TextSpan(
                                text: '$count products',
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stays in sync with the source',
                                      style: AppTextStyles.label(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Imported products keep $storeName's photos and tags. If they edit or remove a product later, your copy updates or is removed too.",
                                      style: AppTextStyles.caption(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed:
                          state.isSubmitting
                              ? null
                              : () => context.read<StoreImportBloc>().add(
                                const StoreImportSimulateApprovedPressed(),
                              ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        'Simulate ${state.sourceStore.name.split(' ').first} approving',
                        style: AppTextStyles.label(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        navigateToOwnStoreProfile(
                          context,
                          fallbackStoreId:
                              context
                                  .read<StoreImportBloc>()
                                  .state
                                  .selectedDestinationId,
                        );
                      },
                      child: Text(
                        'Back to my store',
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
