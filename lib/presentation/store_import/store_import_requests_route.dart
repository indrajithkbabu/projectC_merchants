import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/import_requests/import_requests_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/presentation/store_import/store_import_widgets/import_requests_list_shimmer.dart';

class StoreImportRequestsRoute extends StatefulWidget {
  const StoreImportRequestsRoute({super.key, this.initialTab = 0});

  /// 0 Received, 1 Sent.
  final int initialTab;

  @override
  State<StoreImportRequestsRoute> createState() =>
      _StoreImportRequestsRouteState();
}

class _StoreImportRequestsRouteState extends State<StoreImportRequestsRoute> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab == 1 ? 1 : 0;
  }

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
                  const SizedBox(height: 4),
                  BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                    buildWhen: (p, c) => p.storeName != c.storeName,
                    builder: (context, state) {
                      return Text(
                        state.storeName,
                        style: AppTextStyles.bodySecondary(fontSize: 14),
                      );
                    },
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
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                sizing: StackFit.expand,
                children: [
                  KeyedSubtree(
                    key: const ValueKey('import_requests_received'),
                    child: BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                      builder: (context, state) {
                        return _BatchListPane(
                          items: state.incomingItems,
                          isLoading: state.isLoading,
                          emptyMessage: 'No received requests yet',
                          onRefresh: _pullToRefresh,
                          received: true,
                        );
                      },
                    ),
                  ),
                  KeyedSubtree(
                    key: const ValueKey('import_requests_sent'),
                    child: BlocBuilder<ImportRequestsBloc, ImportRequestsState>(
                      builder: (context, state) {
                        return _BatchListPane(
                          items: state.outgoingItems,
                          isLoading: state.isLoading,
                          emptyMessage: 'No sent requests yet',
                          onRefresh: _pullToRefresh,
                          received: false,
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
              label: 'Received',
              count: incomingPending,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentTab(
              label: 'Sent',
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
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

class _BatchListPane extends StatelessWidget {
  const _BatchListPane({
    required this.items,
    required this.isLoading,
    required this.emptyMessage,
    required this.onRefresh,
    required this.received,
  });

  final List<ImportRequestListItem> items;
  final bool isLoading;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final bool received;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child:
          isLoading && items.isEmpty
              ? const ImportRequestsListShimmer()
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
                padding: AppPadding.screen(top: 12, bottom: 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (received) {
                    return _ReceivedCard(item: item);
                  }
                  return _SentRow(item: item);
                },
              ),
    );
  }
}

/// One Sent card = one product (batch may still hold siblings).
/// Cancel remains batch-level and shows once on the first pending row.
class _SentRow extends StatelessWidget {
  const _SentRow({required this.item});

  final ImportRequestListItem item;

  @override
  Widget build(BuildContext context) {
    final batch = item.batch;
    final product =
        item.focusProduct ??
        (batch.products.isEmpty ? null : batch.products.first);
    final store =
        batch.sourceStore.name.trim().isEmpty
            ? 'Source store'
            : batch.sourceStore.name.trim();
    final when = _ago(batch.createdAt);
    final title =
        (product?.title.trim().isNotEmpty == true)
            ? product!.title.trim()
            : batch.primaryTitle;
    final imageUrl =
        (product?.imageUrl.trim().isNotEmpty == true)
            ? product!.imageUrl.trim()
            : batch.primaryImageUrl;
    final status = _sentStatusLabel(batch: batch, product: product);
    final showCancel = _showSentCancel(item: item, product: product);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child:
                      imageUrl.isEmpty
                          ? ColoredBox(color: AppColors.surfaceSecondary)
                          : ProductMediaImage(
                            path: imageUrl,
                            fit: BoxFit.cover,
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$store · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: status),
            ],
          ),
          if (showCancel) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed:
                  item.isActing
                      ? null
                      : () => context.read<ImportRequestsBloc>().add(
                        ImportRequestsCancelPressed(requestId: batch.id),
                      ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(40),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(
                item.isActing ? '…' : 'Cancel request',
                style: AppTextStyles.button(color: AppColors.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sentStatusLabel({
    required ImportRequestBatch batch,
    required ImportRequestProductRow? product,
  }) {
    if (batch.isCancelled) return batch.status;
    final itemStatus = product?.importStatus.trim() ?? '';
    if (itemStatus.isNotEmpty) return itemStatus;
    return batch.status;
  }

  /// Batch cancel once: first pending product row (or whole card if empty).
  static bool _showSentCancel({
    required ImportRequestListItem item,
    required ImportRequestProductRow? product,
  }) {
    final batch = item.batch;
    if (!batch.canCancel) return false;
    if (batch.products.isEmpty) return true;
    if (product == null || !product.isItemPending) return false;
    final firstPending = batch.products.indexWhere((p) => p.isItemPending);
    return item.productIndex == firstPending;
  }
}

/// One Received card = one product (batch may still hold siblings).
class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard({required this.item});

  final ImportRequestListItem item;

  @override
  Widget build(BuildContext context) {
    final batch = item.batch;
    final store = batch.requesterStore;
    final phone =
        batch.requesterPhone.trim().isNotEmpty
            ? batch.requesterPhone.trim()
            : store.phone.trim();
    final initials = _initials(store.name);
    final product =
        item.focusProduct ??
        (batch.products.isEmpty ? null : batch.products.first);
    final productId = product?.decisionProductId ?? '';
    final itemPending = product?.isItemPending ?? batch.hasActionablePending;
    final actingThis =
        item.isActing &&
        (item.actingProductId.isEmpty ||
            item.actingProductId == productId ||
            item.actingProductId == product?.sourceProductId ||
            item.actingProductId == product?.createdProductId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceSecondary,
                  backgroundImage:
                      store.logo.isEmpty ? null : NetworkImage(store.logo),
                  child:
                      store.logo.isEmpty
                          ? Text(
                            initials,
                            style: AppTextStyles.label(
                              fontWeight: FontWeight.w700,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name.trim().isEmpty
                            ? 'Store'
                            : store.name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(fontWeight: FontWeight.w700),
                      ),
                      if (phone.isNotEmpty)
                        Text(phone, style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                _StatusPill(
                  status:
                      product?.importStatus.isNotEmpty == true
                          ? product!.importStatus
                          : batch.status,
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: _ProductPhoto(product: product),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child:
                itemPending && productId.isNotEmpty
                    ? Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                item.isActing
                                    ? null
                                    : () => context
                                        .read<ImportRequestsBloc>()
                                        .add(
                                          ImportRequestsAcceptPressed(
                                            requestId: batch.id,
                                            productId: productId,
                                          ),
                                        ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.textPrimary,
                              foregroundColor: AppColors.background,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            child: Text(
                              actingThis ? '…' : 'Approve',
                              style: AppTextStyles.button(
                                color: AppColors.background,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                item.isActing
                                    ? null
                                    : () => context
                                        .read<ImportRequestsBloc>()
                                        .add(
                                          ImportRequestsRejectPressed(
                                            requestId: batch.id,
                                            productId: productId,
                                          ),
                                        ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size.fromHeight(44),
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: Text(
                              actingThis ? '…' : 'Decline',
                              style: AppTextStyles.button(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusPill(
                        status:
                            product?.importStatus.isNotEmpty == true
                                ? product!.importStatus
                                : batch.status,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.product});

  final ImportRequestProductRow? product;

  @override
  Widget build(BuildContext context) {
    final url = product?.imageUrl ?? '';
    Widget image;
    if (url.isEmpty) {
      image = ColoredBox(color: AppColors.surfaceSecondary);
    } else {
      image = ProductMediaImage(path: url, fit: BoxFit.cover);
    }
    final row = product;
    if (row == null || row.isItemPending) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned(
          top: 10,
          left: 10,
          child: _StatusPill(status: row.importStatus),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final key = status.trim().toLowerCase();
    final (label, bg, fg) = switch (key) {
      'approved' || 'live' => (
        key == 'live' ? 'Live' : 'Approved',
        AppColors.success.withValues(alpha: 0.16),
        AppColors.success,
      ),
      'declined' || 'rejected' => (
        'Declined',
        AppColors.error.withValues(alpha: 0.14),
        AppColors.error,
      ),
      'partially_approved' => (
        'Partial',
        AppColors.warning.withValues(alpha: 0.16),
        AppColors.warning,
      ),
      'cancelled' || 'deleted' => (
        'Cancelled',
        AppColors.surfaceSecondary,
        AppColors.textSecondary,
      ),
      _ => (
        'Pending',
        AppColors.surfaceSecondary,
        AppColors.textSecondary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

String _ago(DateTime? time) {
  if (time == null) return '';
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 1) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  return '${delta.inDays}d';
}
