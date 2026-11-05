import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

Future<void> showChatDetailsSheet(BuildContext context, ChatThread thread) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final current =
              ChatMockStore.instance.threadById(thread.id) ?? thread;
          return _ChatDetailsSheet(thread: current);
        },
      );
    },
  );
}

class _ChatDetailsSheet extends StatelessWidget {
  const _ChatDetailsSheet({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final store = ChatMockStore.instance;
    final replied = store.repliedBy(thread);
    final names =
        replied.keys.toList()
          ..sort((a, b) => replied[b]!.compareTo(replied[a]!));
    final repliedLabel =
        names.isEmpty
            ? 'No replies yet'
            : names.map((name) => '$name (${replied[name]})').join(', ');
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text('Chat details', style: AppTextStyles.headline(fontSize: 20)),
              const SizedBox(height: 14),
              _DetailRow(label: 'Ticket', value: '#${thread.ticket}'),
              _DetailRow(
                label: 'Open since',
                value:
                    '${chatDayLabel(thread.openedAt)} · ${chatClock(thread.openedAt)}',
              ),
              _DetailRow(
                label: 'Products',
                value:
                    thread.discussions.isEmpty
                        ? 'None yet'
                        : thread.discussions
                            .map((item) => item.title)
                            .join(', '),
              ),
              _DetailRow(label: 'Replied by', value: repliedLabel),
              const SizedBox(height: 8),
              Text(
                'Either of you can reopen it anytime.',
                style: AppTextStyles.caption(fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (thread.status == ChatStatus.open)
                FilledButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    store.closeChat(thread.id);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close chat'),
                )
              else
                OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    store.reopenChat(thread.id);
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Reopen chat',
                    style: AppTextStyles.label(color: AppColors.textPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body(fontSize: 15)),
        ],
      ),
    );
  }
}

Future<void> showAutoReplySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _AutoReplySheet(),
  );
}

class _AutoReplySheet extends StatefulWidget {
  const _AutoReplySheet();

  @override
  State<_AutoReplySheet> createState() => _AutoReplySheetState();
}

class _AutoReplySheetState extends State<_AutoReplySheet> {
  late final TextEditingController _message;
  late final TextEditingController _phrase;

  @override
  void initState() {
    super.initState();
    _message = TextEditingController(
      text: ChatMockStore.instance.autoReplyText,
    );
    _phrase = TextEditingController();
  }

  @override
  void dispose() {
    _message.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: ListenableBuilder(
            listenable: ChatMockStore.instance,
            builder: (context, _) {
              final store = ChatMockStore.instance;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetHandle(),
                    Text(
                      'Auto reply',
                      style: AppTextStyles.headline(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sent once, the first time a customer asks about a product.',
                      style: AppTextStyles.caption(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.autoReplyOn ? 'On' : 'Off',
                            style: AppTextStyles.label(fontSize: 16),
                          ),
                        ),
                        Switch(
                          value: store.autoReplyOn,
                          thumbColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return chatSwitchOn;
                            }
                            return AppColors.border;
                          }),
                          onChanged: (value) => store.setAutoReply(on: value),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _message,
                      minLines: 2,
                      maxLines: 4,
                      style: AppTextStyles.body(fontSize: 15),
                      onChanged:
                          (value) =>
                              store.setAutoReply(text: value, notify: false),
                      decoration: _fieldDecoration('Message'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Quick replies',
                      style: AppTextStyles.label(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shown above the keyboard in every chat.',
                      style: AppTextStyles.caption(),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < store.quickReplies.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          store.quickReplies[i],
                          style: AppTextStyles.body(fontSize: 14),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => store.removeQuickReply(i),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phrase,
                            style: AppTextStyles.body(fontSize: 15),
                            decoration: _fieldDecoration('Add a quick reply'),
                            onSubmitted: _addPhrase,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Add',
                          onPressed: () => _addPhrase(_phrase.text),
                          icon: Icon(
                            Icons.add_circle_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addPhrase(String raw) {
    ChatMockStore.instance.addQuickReply(raw);
    _phrase.clear();
  }
}

Future<ChatProductRef?> showShareProductSheet(BuildContext context) {
  return showModalBottomSheet<ChatProductRef>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _ShareProductSheet(),
  );
}

class _ShareProductSheet extends StatelessWidget {
  const _ShareProductSheet();

  @override
  Widget build(BuildContext context) {
    final products = ChatMockStore.instance.shareCatalog;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Share a product',
                  style: AppTextStyles.headline(fontSize: 20),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(product),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ChatProductThumb(
                              product: product,
                              size: double.infinity,
                              radius: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            product.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.hint(fontSize: 14, fontWeight: FontWeight.w400),
    filled: true,
    fillColor: AppColors.surfaceSecondary,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppPadding.horizontal,
      vertical: 12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

Future<void> showChatProfileSheet(BuildContext context, ChatThread thread) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final current =
              ChatMockStore.instance.threadById(thread.id) ?? thread;
          return _ChatProfileSheet(thread: current);
        },
      );
    },
  );
}

class _ChatProfileSheet extends StatelessWidget {
  const _ChatProfileSheet({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final groups = <String, List<ChatMember>>{};
    for (final member in thread.members) {
      final key =
          member.storeName.trim().isEmpty ? 'People' : member.storeName.trim();
      groups.putIfAbsent(key, () => []).add(member);
    }
    final phone = thread.phone.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Row(
                children: [
                  ChatAvatar(
                    actor: thread.customer,
                    size: 52,
                    group: thread.kind == ChatKind.group,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.customer.name,
                          style: AppTextStyles.label(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(phone, style: AppTextStyles.caption()),
                        if (thread.muted)
                          Text(
                            'Muted',
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mute', style: AppTextStyles.body(fontSize: 16)),
                subtitle: Text(
                  'Stays muted until you turn it off',
                  style: AppTextStyles.caption(fontSize: 12),
                ),
                value: thread.muted,
                onChanged:
                    (value) =>
                        ChatMockStore.instance.setMuted(thread.id, value),
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      entry.key,
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final member in entry.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        member.name,
                        style: AppTextStyles.body(fontSize: 15),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
