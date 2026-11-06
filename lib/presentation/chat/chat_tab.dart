import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

/// Message tab: chats only. Product enquiries and new chats land here.
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AccountProfileBloc>().state.profile;
    final storeId = profile?.ownStore?.id.trim() ?? '';
    final hasStore = storeId.isNotEmpty;
    if (!hasStore) {
      return _MessageBody(
        staffName: profile?.displayName.trim() ?? '',
        storeName: 'My store',
        catalog: const [],
        storesOnly: true,
      );
    }
    return BlocBuilder<StoreProfileBloc, StoreProfileState>(
      buildWhen: (prev, curr) => prev.productsForMedia != curr.productsForMedia,
      builder: (context, state) {
        final products = state.productsForMedia;
        return _MessageBody(
          staffName: profile?.displayName.trim() ?? '',
          storeName: profile?.ownStore?.name.trim() ?? '',
          catalog: [
            for (var i = 0; i < products.length && i < 60; i++)
              _catalogItem(products[i], i),
          ],
          storesOnly: false,
        );
      },
    );
  }

  static ChatProductRef _catalogItem(StoreProduct product, int index) {
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

class _MessageBody extends StatefulWidget {
  const _MessageBody({
    required this.staffName,
    required this.storeName,
    required this.catalog,
    required this.storesOnly,
  });

  final String staffName;
  final String storeName;
  final List<ChatProductRef> catalog;
  final bool storesOnly;

  @override
  State<_MessageBody> createState() => _MessageBodyState();
}

class _MessageBodyState extends State<_MessageBody> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ChatMockStore.instance.syncSession(
      staffName: widget.staffName.isEmpty ? 'You' : widget.staffName,
      storeName: widget.storeName.isEmpty ? 'My store' : widget.storeName,
      catalog: widget.catalog,
    );
    final bottom = FloatingBottomNavBar.reservedHeight(context);
    return ColoredBox(
      color: AppColors.scaffold,
      child: ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final threads = _visible();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ShellTabTitleBar.padding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShellTabTitleBar(
                      title: 'Message',
                      trailing: IconButton(
                        tooltip: 'New chat',
                        onPressed: _newChat,
                        icon: Icon(
                          Icons.add_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _search,
                        //  readOnly: true,
                        showCursor: true,
                        onChanged: (value) => setState(() => _query = value),
                        // onTap: () {
                        //   // _dismissKeyboard();
                        //   Navigator.of(
                        //     context,
                        //   ).pushNamed(Routes.globalSearchRoute);
                        // },
                        style: AppTextStyles.body(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: AppTextStyles.hint(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // TextField(
                    //   controller: _search,
                    //   onChanged: (value) => setState(() => _query = value),
                    //   style: AppTextStyles.body(fontSize: 15),
                    //   decoration: InputDecoration(
                    //     hintText: 'Search',
                    //     hintStyle: AppTextStyles.hint(
                    //       fontSize: 15,
                    //       fontWeight: FontWeight.w400,
                    //     ),
                    //     prefixIcon: Icon(
                    //       Icons.search_rounded,
                    //       color: AppColors.textSecondary,
                    //     ),
                    //     isDense: true,
                    //     filled: true,
                    //     fillColor: AppColors.surface,
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //       borderSide: BorderSide.none,
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 8),
                    _Filters(
                      index: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    threads.isEmpty
                        ? Padding(
                          padding: EdgeInsets.only(bottom: bottom),
                          child: Center(
                            child: Text(
                              'No messages yet',
                              style: AppTextStyles.bodySecondary(),
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: EdgeInsets.only(bottom: bottom),
                          itemCount: threads.length,
                          separatorBuilder:
                              (_, _) => Divider(
                                height: 1,
                                indent: 76,
                                color: AppColors.divider,
                              ),
                          itemBuilder: (context, index) {
                            final thread = threads[index];
                            return _ChatRow(
                              thread: thread,
                              onTap: () => _open(thread),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ChatThread> _visible() {
    final query = _query.trim().toLowerCase();
    return ChatMockStore.instance.inbox(storesOnly: widget.storesOnly).where((
      thread,
    ) {
      switch (_filter) {
        case 1:
          if (thread.unreadCount == 0 && !thread.hasMention) return false;
        case 2:
          final store =
              thread.kind == ChatKind.store ||
              thread.outbound ||
              thread.customer.isStoreAccount;
          if (!store) return false;
        case 3:
          if (thread.kind != ChatKind.group) return false;
      }
      if (query.isEmpty) return true;
      final preview = ChatMockStore.instance.inboxPreview(thread).toLowerCase();
      return thread.customer.name.toLowerCase().contains(query) ||
          preview.contains(query);
    }).toList();
  }

  void _newChat() {
    Navigator.of(context).pushNamed(
      Routes.chatNewRoute,
      arguments: <String, Object?>{
        'contactsBloc': context.read<ContactsBloc>(),
        'storeListingBloc': context.read<StoreListingBloc>(),
      },
    );
  }

  void _open(ChatThread thread) {
    if (thread.discussions.length <= 1) {
      final discussionId =
          thread.discussions.isEmpty ? null : thread.discussions.first.id;
      Navigator.of(context).pushNamed(
        Routes.chatThreadRoute,
        arguments: <String, String?>{
          'chatId': thread.id,
          'openDiscussionId': discussionId,
        },
      );
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.chatDiscussionsRoute,
      arguments: <String, String>{'chatId': thread.id},
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Unread', 'Stores', 'Groups'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          ChoiceChip(
            label: Text(labels[i]),
            selected: index == i,
            onSelected: (_) => onChanged(i),
            visualDensity: VisualDensity.compact,
            labelStyle: AppTextStyles.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            selectedColor: AppColors.surfaceSecondary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: index == i ? AppColors.textPrimary : AppColors.border,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = thread.unreadCount;
    final preview = ChatMockStore.instance.inboxPreview(thread);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(
              actor: thread.customer,
              size: 48,
              group: thread.kind == ChatKind.group,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(fontSize: 16),
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(fontSize: 13),
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
                    fontSize: 12,
                    fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                    color:
                        unread > 0
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (thread.hasMention)
                      Text(
                        '@',
                        style: AppTextStyles.caption(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: chatReadTick,
                        ),
                      ),
                    if (unread > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        unread > 99 ? '99+' : '$unread',
                        style: AppTextStyles.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    if (thread.muted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
