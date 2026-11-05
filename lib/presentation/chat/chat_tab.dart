import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_sheets.dart';

/// Shell tab: merchant Chats list and By product. UI only, backed by
/// [ChatMockStore] until the chat API exists.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  int _segment = 0;

  void _openThread(String chatId, {String? discussionId}) {
    Navigator.of(context).pushNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{
        'chatId': chatId,
        'openDiscussionId': discussionId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AccountProfileBloc>().state.profile;
    final products = context.watch<StoreProfileBloc>().state.productsForMedia;
    final storeName = profile?.ownStore?.name.trim() ?? '';
    final staffName = profile?.displayName.trim() ?? '';
    ChatMockStore.instance.syncSession(
      staffName: staffName.isEmpty ? 'You' : staffName,
      storeName: storeName.isEmpty ? 'My store' : storeName,
      catalog: [
        for (var i = 0; i < products.length && i < 60; i++)
          _catalogItem(products[i], i),
      ],
    );

    final bottom = FloatingBottomNavBar.reservedHeight(context);
    final signedIn = staffName.isEmpty ? 'You' : staffName;
    final storeLabel = storeName.isEmpty ? 'My store' : storeName;

    return ColoredBox(
      color: AppColors.scaffold,
      child: ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final store = ChatMockStore.instance;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ShellTabTitleBar.padding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShellTabTitleBar(
                      title: 'Chats',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // _AutoReplyPill(
                          //   on: store.autoReplyOn,
                          //   onTap: () => showAutoReplySheet(context),
                          // ),
                          IconButton(
                            tooltip: 'New chat',
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(Routes.chatNewRoute);
                            },
                            icon: Icon(
                              Icons.add_rounded,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$storeLabel · signed in as $signedIn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _SegmentBar(
                      index: _segment,
                      onChanged: (value) => setState(() => _segment = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _segment == 0
                        ? _ChatList(
                          threads: store.visibleThreads,
                          bottom: bottom,
                          onOpen: _openThread,
                        )
                        : _ProductList(
                          groups: store.productGroups,
                          bottom: bottom,
                          onOpen: _openThread,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  ChatProductRef _catalogItem(StoreProduct product, int index) {
    final detail =
        product.meta.trim().isEmpty ? 'Product' : product.meta.trim();
    return ChatMockStore.productFromTitle(
      id: product.id,
      title: product.title,
      detail: detail,
      imageUrl: product.primaryImagePath ?? '',
      toneIndex: product.toneIndex == 0 ? index : product.toneIndex,
    );
  }
}

class _AutoReplyPill extends StatelessWidget {
  const _AutoReplyPill({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Auto · ${on ? 'On' : 'Off'}',
            style: AppTextStyles.caption(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: on ? chatSwitchOn : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Chats',
            selected: index == 0,
            onTap: () => onChanged(0),
          ),
          _Segment(
            label: 'By product',
            selected: index == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.threads,
    required this.bottom,
    required this.onOpen,
  });

  final List<ChatThread> threads;
  final double bottom;
  final void Function(String chatId, {String? discussionId}) onOpen;

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, bottom),
        child: Text(
          'No chats yet. Start one with a customer who follows your store.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottom),
      itemCount: threads.length,
      separatorBuilder:
          (_, _) => Divider(height: 1, indent: 76, color: AppColors.divider),
      itemBuilder: (context, index) {
        final thread = threads[index];
        final last = thread.lastContent;
        final unread = thread.unreadCount;
        return InkWell(
          onTap: () => onOpen(thread.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppPadding.horizontal,
              vertical: 10,
            ),
            child: Row(
              children: [
                ChatAvatar(actor: thread.customer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              thread.customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label(
                                fontSize: 16,
                                fontWeight:
                                    unread > 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (thread.customer.isStoreAccount) ...[
                            const SizedBox(width: 6),
                            const ChatStoreTag(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (last != null &&
                              last.mine &&
                              !thread.customerTyping) ...[
                            ChatReceiptTicks(receipt: last.receipt),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              thread.previewText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                fontSize: 13,
                                fontWeight:
                                    unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color:
                                    thread.customerTyping
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chatListTime(thread.lastActivity),
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        fontWeight:
                            unread > 0 ? FontWeight.w700 : FontWeight.w400,
                        color:
                            unread > 0
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ChatUnreadBadge(count: unread),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.groups,
    required this.bottom,
    required this.onOpen,
  });

  final List<ChatProductGroup> groups;
  final double bottom;
  final void Function(String chatId, {String? discussionId}) onOpen;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, bottom),
        child: Text(
          'No product questions yet.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppPadding.horizontal,
        0,
        AppPadding.horizontal,
        bottom,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = groups[index];
        final count = group.customerCount;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChatProductThumb(product: group.product, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.product.name,
                          style: AppTextStyles.label(fontSize: 15),
                        ),
                        Text(
                          group.product.detail,
                          style: AppTextStyles.caption(fontSize: 12),
                        ),
                        Text(
                          '$count customer${count == 1 ? '' : 's'} asked',
                          style: AppTextStyles.caption(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final customer in group.customers)
                    Material(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap:
                            () => onOpen(
                              customer.threadId,
                              discussionId: customer.discussionId,
                            ),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                customer.name,
                                style: AppTextStyles.caption(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (customer.unread > 0) ...[
                                const SizedBox(width: 6),
                                ChatUnreadBadge(count: customer.unread),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
