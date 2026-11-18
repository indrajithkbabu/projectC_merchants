import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/chat_inbox/chat_inbox_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/profile_sheets.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

/// Message tab: chats only. Product enquiries and new chats land here.
class ChatTab extends StatelessWidget {
  const ChatTab({
    super.key,
    this.activeProfileName,
    this.storesOnly,
    this.storeId,
  });

  /// Active actable profile display name for the "as {name}" subtitle.
  final String? activeProfileName;

  /// When set, overrides own-store detection for inbox scoping.
  final bool? storesOnly;

  /// Active store id when acting as a store profile.
  final String? storeId;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AccountProfileBloc>().state.profile;
    final resolvedStoreId =
        (storeId?.trim().isNotEmpty == true)
            ? storeId!.trim()
            : (profile?.ownStore?.id.trim() ?? '');
    final asStore =
        storesOnly == false
            ? true
            : (storesOnly == true ? false : resolvedStoreId.isNotEmpty);
    final asName =
        (activeProfileName?.trim().isNotEmpty == true)
            ? activeProfileName!.trim()
            : (asStore
                ? (profile?.ownStore?.name.trim() ?? '')
                : (profile?.displayName.trim() ?? ''));

    if (!asStore) {
      return _MessageBody(
        staffName: profile?.displayName.trim() ?? '',
        storeName: asName.isEmpty ? 'Personal' : asName,
        catalog: const [],
        storesOnly: true,
        asProfileName: asName,
      );
    }

    StoreProfileBloc? storeBloc;
    try {
      storeBloc = context.read<StoreProfileBloc>();
    } catch (_) {
      storeBloc = null;
    }
    if (storeBloc == null) {
      return _MessageBody(
        staffName: profile?.displayName.trim() ?? '',
        storeName: asName.isEmpty ? 'My store' : asName,
        catalog: const [],
        storesOnly: false,
        asProfileName: asName,
      );
    }

    return BlocBuilder<StoreProfileBloc, StoreProfileState>(
      buildWhen: (prev, curr) => prev.productsForMedia != curr.productsForMedia,
      builder: (context, state) {
        final products = state.productsForMedia;
        return _MessageBody(
          staffName: profile?.displayName.trim() ?? '',
          storeName:
              asName.isNotEmpty
                  ? asName
                  : (profile?.ownStore?.name.trim() ?? ''),
          catalog: [
            for (var i = 0; i < products.length && i < 60; i++)
              _catalogItem(products[i], i),
          ],
          storesOnly: false,
          asProfileName: asName,
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
    this.asProfileName,
  });

  final String staffName;
  final String storeName;
  final List<ChatProductRef> catalog;
  final bool storesOnly;
  final String? asProfileName;

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
      child: BlocBuilder<ChatInboxBloc, ChatInboxState>(
        builder: (context, inbox) {
          final threads = _visible(inbox.items);
          final canCompose = inbox.writesEnabled && !inbox.unavailable;
          final profileName =
              (widget.asProfileName ?? '').trim().isNotEmpty
                  ? widget.asProfileName!.trim()
                  : (widget.storeName.trim().isEmpty
                      ? 'Store'
                      : widget.storeName.trim());
          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: ShellTabTitleBar.padding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: ShellTabTitleBar.rowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => showProfileSwitcherSheet(context),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profileName,
                                      style: AppTextStyles.headline(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textPrimary,
                                    size: 26,
                                  ),
                                ],
                              ),
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
                            onChanged:
                                (value) => setState(() => _query = value),
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
                        if (inbox.isLoadingMore)
                          const LinearProgressIndicator(minHeight: 2),
                        if (inbox.errorMessage != null &&
                            inbox.items.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              inbox.errorMessage!,
                              style: AppTextStyles.caption(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child:
                          threads.isEmpty
                              ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(bottom: bottom + 72),
                                children: [
                                  SizedBox(
                                    height: 280,
                                    child: Center(
                                      child: _InboxStatus(inbox: inbox),
                                    ),
                                  ),
                                ],
                              )
                              : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(bottom: bottom + 72),
                                itemCount: threads.length,
                                separatorBuilder:
                                    (_, _) => Divider(
                                      height: 1,
                                      indent: 76,
                                      color: AppColors.divider,
                                    ),
                                itemBuilder: (context, index) {
                                  return _ChatRow(relationship: threads[index]);
                                },
                              ),
                    ),
                  ),
                ],
              ),
              if (canCompose)
                Positioned(
                  right: 16,
                  bottom: bottom + 8,
                  child: Material(
                    //   color: chatSend,
                    color: Color(0xFF1F7A4D),
                    elevation: 6,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: _newChat,
                      borderRadius: BorderRadius.circular(18),
                      child: const SizedBox(
                        width: 58,
                        height: 58,
                        child: Icon(
                          Icons.add_comment_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    final bloc = context.read<ChatInboxBloc>();
    final done = bloc.stream.firstWhere(
      (state) => !state.isLoading && !state.isRefreshing,
    );
    bloc.add(const ChatInboxRefreshed());
    await done;
  }

  List<ChatRelationship> _visible(List<ChatRelationship> items) {
    final query = _query.trim().toLowerCase();
    return items.where((relationship) {
      final other = relationship.otherSide;
      final isStore = other?.isStore == true;
      if (widget.storesOnly && !isStore) return false;
      if (_filter == 1 && relationship.unreadCount <= 0) return false;
      if (_filter == 2 && isStore) return false;
      if (_filter == 3 && !isStore) return false;
      if (query.isEmpty) return true;
      final name = (other?.name ?? '').toLowerCase();
      return name.contains(query) ||
          _preview(relationship.lastMessage).toLowerCase().contains(query);
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
}

String _preview(ChatApiMessage? message) {
  if (message == null) return '';
  if (message.removed) return 'Message removed';
  final text = message.body?.trim() ?? '';
  if (text.isNotEmpty) return text;
  if (message.photos.isNotEmpty) return 'Photo';
  return '';
}

class _InboxStatus extends StatelessWidget {
  const _InboxStatus({required this.inbox});

  final ChatInboxState inbox;

  @override
  Widget build(BuildContext context) {
    if (inbox.unavailable) {
      return Text(
        'Chat is unavailable right now.',
        style: AppTextStyles.bodySecondary(),
        textAlign: TextAlign.center,
      );
    }
    if (!inbox.hasFetched || inbox.isLoading) {
      return const CircularProgressIndicator();
    }
    final error = inbox.errorMessage;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            style: AppTextStyles.bodySecondary(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
            },
            child: const Text('Try again'),
          ),
        ],
      );
    }
    return Text('No messages yet', style: AppTextStyles.bodySecondary());
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Unread', 'Customers', 'Stores'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          ChoiceChip(
            label: Text(labels[i]),
            selected: index == i,
            showCheckmark: false,
            onSelected: (_) => onChanged(i),
            visualDensity: VisualDensity.compact,
            labelStyle: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: index == i ? Colors.white : AppColors.textPrimary,
            ),
            selectedColor: const Color(0xFF1F7A4D),
            backgroundColor: AppColors.surfaceSecondary,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.relationship});

  final ChatRelationship relationship;

  @override
  Widget build(BuildContext context) {
    final other = relationship.otherSide;
    final name =
        (other?.name.trim().isNotEmpty == true) ? other!.name.trim() : 'Chat';
    final unread = relationship.unreadCount;
    final preview = _preview(relationship.lastMessage);
    final at =
        relationship.lastActivityAt ?? relationship.lastMessage?.createdAt;
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          Routes.chatThreadRoute,
          arguments: <String, Object?>{
            'chatId': relationship.id,
            'api': true,
            'title': name,
            'isStore': other?.isStore == true,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(
              actor: ChatActor(
                id: other?.id ?? relationship.id,
                name: name,
                isStoreAccount: other?.isStore == true,
              ),
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                  at == null ? '' : chatListTime(at),
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
                    if (unread > 0)
                      Text(
                        unread > 99 ? '99+' : '$unread',
                        style: AppTextStyles.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    if (relationship.muted) ...[
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
