import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/import_requests/import_requests_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';

class StoreImportRequestsRoute extends StatefulWidget {
  const StoreImportRequestsRoute({super.key});

  @override
  State<StoreImportRequestsRoute> createState() =>
      _StoreImportRequestsRouteState();
}

class _StoreImportRequestsRouteState extends State<StoreImportRequestsRoute> {
  int _tabIndex = 0;

  Future<void> _pullToRefresh() async {
    final bloc = context.read<ImportRequestsBloc>();
    if (bloc.state.isLoading) {
      await bloc.stream.firstWhere((s) => !s.isLoading);
      return;
    }
    bloc.add(const ImportRequestsRefreshed());
    await bloc.stream.firstWhere((s) => s.isLoading);
    await bloc.stream.firstWhere((s) => !s.isLoading);
  }

  void _selectTab(int index) {
    if (!mounted || _tabIndex == index) return;
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ImportRequestsBloc, ImportRequestsState>(
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
            context.read<ImportRequestsBloc>().add(
              const ImportRequestsClearMessage(),
            );
          },
        ),
        BlocListener<ImportRequestsBloc, ImportRequestsState>(
          listenWhen:
              (prev, curr) =>
                  curr.infoMessage != null &&
                  curr.infoMessage != prev.infoMessage,
          listener: (context, state) {
            final message = state.infoMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<ImportRequestsBloc>().add(
              const ImportRequestsClearMessage(),
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context) + 8,
                bottom: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 8),
                  Text('Import requests', style: AppTextStyles.title()),
                  const SizedBox(height: 6),
                  Text(
                    'Review requests to use products from your store, or check the status of requests you sent.',
                    style: AppTextStyles.bodySecondary(fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                    buildWhen:
                        (prev, curr) =>
                            prev.pendingIncoming.length !=
                                curr.pendingIncoming.length ||
                            prev.pendingOutgoing.length !=
                                curr.pendingOutgoing.length,
                    builder: (context, state) {
                      return _SegmentedTabs(
                        selectedIndex: _tabIndex,
                        incomingPending: state.pendingIncoming.length,
                        sentPending: state.pendingOutgoing.length,
                        onChanged: _selectTab,
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                sizing: StackFit.expand,
                children: [
                  KeyedSubtree(
                    key: const ValueKey('import_requests_incoming'),
                    child: BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                      buildWhen:
                          (prev, curr) =>
                              prev.isLoading != curr.isLoading ||
                              prev.incomingItems != curr.incomingItems ||
                              prev.actingRequestId != curr.actingRequestId ||
                              prev.items != curr.items,
                      builder: (context, state) {
                        return _RequestsListPane(
                          items: state.incomingItems,
                          isLoading: state.isLoading,
                          emptyMessage: 'No incoming requests yet',
                          onRefresh: _pullToRefresh,
                        );
                      },
                    ),
                  ),
                  KeyedSubtree(
                    key: const ValueKey('import_requests_sent'),
                    child: BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                      buildWhen:
                          (prev, curr) =>
                              prev.isLoading != curr.isLoading ||
                              prev.outgoingItems != curr.outgoingItems ||
                              prev.actingRequestId != curr.actingRequestId ||
                              prev.items != curr.items,
                      builder: (context, state) {
                        return _RequestsListPane(
                          items: state.outgoingItems,
                          isLoading: state.isLoading,
                          emptyMessage: 'No sent requests yet',
                          onRefresh: _pullToRefresh,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selectedIndex,
    required this.incomingPending,
    required this.sentPending,
    required this.onChanged,
  });

  final int selectedIndex;
  final int incomingPending;
  final int sentPending;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              label: 'Incoming',
              icon: Icons.move_to_inbox_rounded,
              count: incomingPending,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentTab(
              label: 'Sent',
              icon: Icons.outbox_rounded,
              count: sentPending,
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final labelColor =
        selected ? AppColors.textPrimary : AppColors.textSecondary;

    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: AppTextStyles.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          selected
                              ? AppColors.textOnPrimary
                              : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsListPane extends StatelessWidget {
  const _RequestsListPane({
    required this.items,
    required this.isLoading,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<ImportRequestItem> items;
  final bool isLoading;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child:
          isLoading && items.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
              : items.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppPadding.screen(top: 48, bottom: 24),
                children: [
                  Center(
                    child: Text(
                      emptyMessage,
                      style: AppTextStyles.bodySecondary(),
                    ),
                  ),
                ],
              )
              : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppPadding.screen(top: 8, bottom: 24),
                itemCount: items.length,
                separatorBuilder:
                    (_, __) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  return _ImportRequestTile(item: items[index]);
                },
              ),
    );
  }
}

class _ImportRequestTile extends StatelessWidget {
  const _ImportRequestTile({required this.item});

  final ImportRequestItem item;

  @override
  Widget build(BuildContext context) {
    final pending = item.request.isPending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isIncoming
                      ? Icons.move_to_inbox_rounded
                      : Icons.outbox_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTextStyles.caption(fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: item.request.status),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            if (item.isIncoming)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          item.isActing
                              ? null
                              : () => context.read<ImportRequestsBloc>().add(
                                ImportRequestsRejectPressed(item.request.id),
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: AppTextStyles.label(
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          item.isActing
                              ? null
                              : () => context.read<ImportRequestsBloc>().add(
                                ImportRequestsAcceptPressed(item.request.id),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          item.isActing
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnPrimary,
                                ),
                              )
                              : Text(
                                'Accept',
                                style: AppTextStyles.label(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'You’ll be notified here when they respond.',
                style: AppTextStyles.caption(fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'pending' => ('Pending', AppColors.warning, AppColors.warningSoft),
      'approved' => (
        'Accepted',
        AppColors.success,
        AppColors.success.withValues(alpha: 0.12),
      ),
      'rejected' => (
        'Rejected',
        AppColors.error,
        AppColors.error.withValues(alpha: 0.12),
      ),
      'cancelled' => (
        'Cancelled',
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
      ),
      _ => (status, AppColors.textSecondary, AppColors.surfaceSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
