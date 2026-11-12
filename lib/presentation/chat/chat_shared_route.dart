import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

void openChatShared(BuildContext context, String chatId) {
  Navigator.of(context).pushNamed(
    Routes.chatSharedRoute,
    arguments: <String, String>{'chatId': chatId},
  );
}

class ChatSharedRoute extends StatelessWidget {
  const ChatSharedRoute({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.scaffold,
      child: DefaultTabController(
        length: 3,
        child: ListenableBuilder(
          listenable: ChatMockStore.instance,
          builder: (context, _) {
            final thread = ChatMockStore.instance.threadById(chatId);
            if (thread == null) {
              return const Center(child: Text('This chat is unavailable'));
            }
            final entries = chatSharedEntries(
              thread,
              ChatMockStore.instance.storeName,
            );
            final products =
                entries
                    .where((entry) => entry.kind == ChatSharedKind.product)
                    .toList();
            final photos =
                entries
                    .where((entry) => entry.kind == ChatSharedKind.photo)
                    .toList();
            final files =
                entries
                    .where((entry) => entry.kind == ChatSharedKind.file)
                    .toList();
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: ScreenWrapper.statusBarTop(context),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.backIcon,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Shared',
                          style: AppTextStyles.headline(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Products'),
                    Tab(text: 'Photos'),
                    Tab(text: 'Files'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Products(thread: thread, entries: products),
                      _Photos(thread: thread, entries: photos),
                      _Files(thread: thread, entries: files),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Products extends StatelessWidget {
  const _Products({required this.thread, required this.entries});

  final ChatThread thread;
  final List<ChatSharedEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _Empty(label: 'No products shared yet');
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final product = entry.product;
        return ListTile(
          leading:
              product == null
                  ? null
                  : ChatProductThumb(product: product, size: 48, radius: 8),
          title: Text(entry.title, style: AppTextStyles.body(fontSize: 15)),
          subtitle: Text(entry.subtitle, style: AppTextStyles.caption()),
          onTap: () => _openDiscussion(context, thread, entry.discussionId),
        );
      },
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.thread, required this.entries});

  final ChatThread thread;
  final List<ChatSharedEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _Empty(label: 'No photos yet');
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final message = entries[index].message;
        if (message == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => _PhotoViewer(
                        thread: thread,
                        entries: entries,
                        initial: index,
                      ),
                ),
              ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ChatPhotoView(
                message: message,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                radius: 0,
              );
            },
          ),
        );
      },
    );
  }
}

class _Files extends StatelessWidget {
  const _Files({required this.thread, required this.entries});

  final ChatThread thread;
  final List<ChatSharedEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _Empty(label: 'No files yet');
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final discussion = thread.discussionById(entry.discussionId);
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(entry.title, style: AppTextStyles.body(fontSize: 15)),
          subtitle: Text(
            '${entry.sender} · ${discussion?.title ?? 'Chat'} · ${chatDayLabel(entry.at)}',
            style: AppTextStyles.caption(),
          ),
          onTap: () => _openDiscussion(context, thread, entry.discussionId),
        );
      },
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.thread,
    required this.entries,
    required this.initial,
  });

  final ChatThread thread;
  final List<ChatSharedEntry> entries;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initial;
    _page = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entries[_index];
    final discussion = widget.thread.discussionById(entry.discussionId);
    final message = entry.message;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          entry.sender.isEmpty ? 'Photo' : entry.sender,
          style: AppTextStyles.label(fontSize: 16, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: widget.entries.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.entries[index].message;
                if (item == null) return const SizedBox.shrink();
                return Center(
                  child: ChatPhotoView(
                    message: item,
                    width: MediaQuery.sizeOf(context).width,
                    height: MediaQuery.sizeOf(context).width,
                    radius: 0,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Text(
                  discussion?.title ?? 'Chat',
                  style: AppTextStyles.body(fontSize: 14, color: Colors.white),
                ),
                if (message != null && message.text.trim().isNotEmpty)
                  Text(
                    message.text,
                    style: AppTextStyles.caption(color: Colors.white70),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Previous',
                      onPressed:
                          _index == 0
                              ? null
                              : () => _page.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    TextButton(
                      onPressed:
                          () => _openDiscussion(
                            context,
                            widget.thread,
                            entry.discussionId,
                          ),
                      child: const Text('Show in chat'),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed:
                          _index >= widget.entries.length - 1
                              ? null
                              : () => _page.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label, style: AppTextStyles.bodySecondary()));
  }
}

void _openDiscussion(BuildContext context, ChatThread thread, String discussionId) {
  Navigator.of(context).pushNamed(
    Routes.chatThreadRoute,
    arguments: <String, String?>{
      'chatId': thread.id,
      'openDiscussionId': discussionId.isEmpty ? null : discussionId,
    },
  );
}
