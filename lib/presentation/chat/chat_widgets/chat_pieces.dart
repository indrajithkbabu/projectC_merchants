import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/webservice/chat/chat_repository.dart';

const chatReadTick = Color(0xFF53BDEB);
const chatSwitchOn = Color(0xFF16A34A);

/// WhatsApp thread colors. Right side is green, left side is white, text is black.
/// Night keeps the dark WhatsApp pair so the text stays readable.
Color get chatWallpaper =>
    AppColors.isNight ? const Color(0xFF0B141A) : const Color(0xFFECE5DD);

Color get chatBar =>
    AppColors.isNight ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);

Color get chatIncoming =>
    AppColors.isNight ? const Color(0xFF202C33) : Colors.white;

Color get chatOutgoing =>
    AppColors.isNight ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);

Color get chatSenderName =>
    AppColors.isNight ? const Color(0xFF8FB9AE) : const Color(0xFF1D6B5A);

Color get chatField =>
    AppColors.isNight ? const Color(0xFF2A3942) : Colors.white;

Color get chatInk =>
    AppColors.isNight ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);

Color get chatMuted =>
    AppColors.isNight ? const Color(0xFF8696A0) : const Color(0xFF667781);

Color get chatSend => const Color(0xFF00A884);

/// Reply name and the bar beside a quoted message.
Color get chatQuoteAccent =>
    AppColors.isNight ? const Color(0xFF06CF9C) : const Color(0xFF008069);

const _avatarPalette = <Color>[
  Color(0xFF2AABEE),
  Color(0xFFE67E22),
  Color(0xFF8E44AD),
  Color(0xFF16A085),
  Color(0xFFE74C3C),
  Color(0xFF2980B9),
  Color(0xFF27AE60),
  Color(0xFFD35400),
];

Color chatAvatarColor(String seed) {
  if (seed.isEmpty) return _avatarPalette.first;
  final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return _avatarPalette[hash % _avatarPalette.length];
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.actor,
    this.size = 48,
    this.group = false,
  });

  final ChatActor actor;
  final double size;
  final bool group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chatAvatarColor(actor.id),
        shape: BoxShape.circle,
      ),
      child:
          group
              ? Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: size * 0.5,
              )
              : Text(
                actor.initials,
                style: AppTextStyles.caption(
                  fontSize: size < 36 ? 11 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
    );
  }
}

class ChatProductThumb extends StatelessWidget {
  const ChatProductThumb({
    super.key,
    required this.product,
    this.size = 44,
    this.radius = 10,
  });

  final ChatProductRef product;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl.trim();
    final image =
        url.isEmpty
            ? _swatch()
            : Image.network(
              url,
              fit: BoxFit.cover,
              width: size.isFinite ? size : null,
              height: size.isFinite ? size : null,
              errorBuilder: (_, _, _) => _swatch(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _swatch();
              },
            );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child:
          size.isFinite
              ? SizedBox(width: size, height: size, child: image)
              : SizedBox.expand(child: image),
    );
  }

  Widget _swatch() {
    return ColoredBox(
      color: product.color,
      child: Center(
        child: Text(
          product.initial,
          style: AppTextStyles.caption(
            fontSize: size < 32 ? 11 : 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ChatUnreadBadge extends StatelessWidget {
  const ChatUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class ChatReceiptTicks extends StatelessWidget {
  const ChatReceiptTicks({
    super.key,
    required this.receipt,
    this.size = 14,
    this.idleColor,
  });

  final ChatReceipt? receipt;
  final double size;

  /// Tick color before the message is read. Read stays blue.
  final Color? idleColor;

  @override
  Widget build(BuildContext context) {
    if (receipt == null) return const SizedBox.shrink();
    final read = receipt == ChatReceipt.read;
    final color = read ? chatReadTick : (idleColor ?? chatMuted);
    return Icon(
      receipt == ChatReceipt.sent ? Icons.done_rounded : Icons.done_all_rounded,
      size: size,
      color: color,
    );
  }
}

class ChatStoreTag extends StatelessWidget {
  const ChatStoreTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Store',
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class ChatSwipeToReply extends StatefulWidget {
  const ChatSwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
  });

  final Widget child;
  final VoidCallback onReply;

  @override
  State<ChatSwipeToReply> createState() => _ChatSwipeToReplyState();
}

class _ChatSwipeToReplyState extends State<ChatSwipeToReply> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dx = (_dx + details.delta.dx).clamp(0, 72);
        });
      },
      onHorizontalDragEnd: (_) {
        final fire = _dx > 48;
        setState(() => _dx = 0);
        if (fire) {
          HapticFeedback.selectionClick();
          widget.onReply();
        }
      },
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dx > 6)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.reply_rounded,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: _dx / 72),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

class ChatTypingDots extends StatefulWidget {
  const ChatTypingDots({super.key});

  @override
  State<ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<ChatTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 64, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _otherBubble(),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: chatMuted.withValues(
                        alpha: _dotAlpha(i, _controller.value),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _dotAlpha(int index, double t) {
    final phase = (t + index * 0.2) % 1;
    return 0.35 + (phase < 0.5 ? phase : 1 - phase);
  }
}

Color _otherBubble() => chatIncoming;

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onReply,
    this.onLongPress,
    this.onSecondaryTap,
    this.onTap,
    this.onProductTap,
    this.senderLabel,
    this.senderStore,
    this.alignRight,
  });

  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onTap;
  final ValueChanged<ChatProductRef>? onProductTap;
  final String? senderLabel;
  final String? senderStore;

  /// Right side is your own bubble. Defaults to store-side messages.
  final bool? alignRight;

  @override
  Widget build(BuildContext context) {
    final mineSide = alignRight ?? message.side == ChatSenderSide.merchant;
    final outgoing = mineSide;
    final textColor = chatInk;
    final timeColor = chatMuted;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final label = senderLabel?.trim() ?? '';
    final store = senderStore?.trim() ?? '';
    final fill = outgoing ? chatOutgoing : chatIncoming;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(outgoing ? 8 : 0),
      topRight: Radius.circular(outgoing ? 0 : 8),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    final caption = _bubbleBody(message);
    final isPhoto = message.kind == ChatMessageKind.photo;
    final receipt =
        message.mine ? (message.receipt ?? ChatReceipt.sent) : null;
    final photoWidth = math.min(maxWidth, 300.0);
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isPhoto ? photoWidth : maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: isPhoto ? BorderRadius.circular(10) : radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: isPhoto ? BorderRadius.circular(10) : radius,
          child: ColoredBox(
            color: fill,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: textColor),
              child: isPhoto
                  ? _PhotoBubbleBody(
                      message: message,
                      maxWidth: photoWidth,
                      caption: caption,
                      textColor: textColor,
                      timeColor: timeColor,
                      receipt: receipt,
                      label: label,
                      store: store,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 6, 3),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (message.starred)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 2),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: chatTeamNote,
                                ),
                              ),
                            if (message.teamOnly) const _TeamOnlyLabel(),
                            if (label.isNotEmpty)
                              _SenderLabel(label: label, store: store),
                            if (message.quote != null)
                              _QuoteBlock(quote: message.quote!),
                            if (message.kind == ChatMessageKind.file)
                              _FileRow(name: message.previewBody())
                            else if (message.kind == ChatMessageKind.basket)
                              _BasketGrid(
                                message: message,
                                onProductTap: onProductTap,
                              )
                            else if (message.products.isNotEmpty)
                              _ProductCard(
                                product: message.products.first,
                                suggested: message.suggestedAlternative,
                              ),
                            _TextWithTime(
                              text: caption,
                              mentions: message.mentions,
                              textStyle: AppTextStyles.body(
                                fontSize: 15.5,
                                height: 1.25,
                                color: textColor,
                              ),
                              time: chatClock(message.at),
                              timeColor: timeColor,
                              receipt: receipt,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    return ChatSwipeToReply(
      onReply: onReply,
      child: GestureDetector(
        onTap: onTap ?? (isPhoto ? () => openChatPhoto(context, message) : null),
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mineSide ? 20 : 2,
            2,
            mineSide ? 2 : 20,
            2,
          ),
          child: bubble,
        ),
      ),
    );
  }
}

class _PhotoBubbleBody extends StatelessWidget {
  const _PhotoBubbleBody({
    required this.message,
    required this.maxWidth,
    required this.caption,
    required this.textColor,
    required this.timeColor,
    required this.receipt,
    required this.label,
    required this.store,
  });

  final ChatMessage message;
  final double maxWidth;
  final String caption;
  final Color textColor;
  final Color timeColor;
  final ChatReceipt? receipt;
  final String label;
  final String store;

  @override
  Widget build(BuildContext context) {
    final bare =
        caption.trim().isEmpty && label.isEmpty && message.quote == null;
    final photo = _SizedChatPhoto(
      message: message,
      maxWidth: maxWidth,
      showTime: caption.trim().isEmpty,
      time: chatClock(message.at),
      receipt: receipt,
      showBadges: bare,
    );
    if (bare) return photo;
    final hasHeader =
        message.starred ||
        message.teamOnly ||
        label.isNotEmpty ||
        message.quote != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.starred)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: chatTeamNote,
                    ),
                  ),
                if (message.teamOnly) const _TeamOnlyLabel(),
                if (label.isNotEmpty) _SenderLabel(label: label, store: store),
                if (message.quote != null) _QuoteBlock(quote: message.quote!),
              ],
            ),
          ),
        photo,
        if (caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 3),
            child: _TextWithTime(
              text: caption,
              mentions: message.mentions,
              textStyle: AppTextStyles.body(
                fontSize: 15.5,
                height: 1.25,
                color: textColor,
              ),
              time: chatClock(message.at),
              timeColor: timeColor,
              receipt: receipt,
            ),
          ),
      ],
    );
  }
}

class _TeamOnlyLabel extends StatelessWidget {
  const _TeamOnlyLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 12, color: chatTeamNote),
          const SizedBox(width: 4),
          Text(
            'Only your team',
            style: AppTextStyles.caption(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chatTeamNote,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderLabel extends StatelessWidget {
  const _SenderLabel({required this.label, required this.store});

  final String label;
  final String store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: AppTextStyles.caption(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: chatSenderName,
              ),
            ),
            if (store.isNotEmpty)
              TextSpan(
                text: '  $store',
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: chatMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _bubbleBody(ChatMessage message) {
  if (message.kind == ChatMessageKind.file) return '';
  final text = message.text.trim();
  if (text.isEmpty) return '';
  if (message.kind == ChatMessageKind.productShare &&
      message.products.isNotEmpty &&
      text == message.products.first.name) {
    return '';
  }
  return message.text;
}

/// The message stays on the left of the bubble. The time sits under it,
/// at the right edge.
class _TextWithTime extends StatelessWidget {
  const _TextWithTime({
    required this.text,
    required this.mentions,
    required this.textStyle,
    required this.time,
    required this.timeColor,
    this.receipt,
  });

  final String text;
  final List<String> mentions;
  final TextStyle textStyle;
  final String time;
  final Color timeColor;
  final ChatReceipt? receipt;

  @override
  Widget build(BuildContext context) {
    final clock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: AppTextStyles.caption(fontSize: 11, color: timeColor),
        ),
        if (receipt != null) ...[
          const SizedBox(width: 3),
          ChatReceiptTicks(receipt: receipt, size: 14),
        ],
      ],
    );
    if (text.trim().isEmpty) {
      return Align(alignment: Alignment.centerRight, child: clock);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MentionText(text: text, mentions: mentions, style: textStyle),
        const SizedBox(height: 2),
        Align(alignment: Alignment.centerRight, child: clock),
      ],
    );
  }
}

class _MentionText extends StatelessWidget {
  const _MentionText({
    required this.text,
    required this.mentions,
    required this.style,
  });

  final String text;
  final List<String> mentions;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty || !text.contains('@')) {
      return Text(text, style: style);
    }
    final tokens =
        mentions
            .map((name) => name.split(RegExp(r'\s+')).first)
            .where((name) => name.isNotEmpty)
            .toSet();
    final pattern = RegExp(r'@([A-Za-z][A-Za-z0-9]*)');
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(1)!;
      final hit = tokens.any(
        (name) => name.toLowerCase() == token.toLowerCase(),
      );
      spans.add(
        TextSpan(
          text: match.group(0),
          style:
              hit
                  ? style.copyWith(
                    color: chatReadTick,
                    fontWeight: FontWeight.w700,
                  )
                  : style,
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quote});

  final ChatQuote quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: chatQuoteAccent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.senderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: chatQuoteAccent,
                  ),
                ),
                if (quote.product != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ChatProductThumb(
                        product: quote.product!,
                        size: 28,
                        radius: 6,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: _quoteCaption(quote.previewText)),
                    ],
                  ),
                ] else if (quote.previewText.isNotEmpty)
                  _quoteCaption(quote.previewText),
              ],
            ),
          ),
          if (quote.hasPhoto) ...[
            const SizedBox(width: 8),
            ChatQuoteThumb(quote: quote),
          ],
        ],
      ),
    );
  }
}

Widget _quoteCaption(String text) {
  return Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppTextStyles.caption(fontSize: 12, color: chatMuted),
  );
}

class ChatQuoteThumb extends StatelessWidget {
  const ChatQuoteThumb({super.key, required this.quote, this.size = 42});

  final ChatQuote quote;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!quote.hasPhoto) return const SizedBox.shrink();
    return ChatPhotoView(
      message: ChatMessage(
        id: quote.remotePhotoId.trim().isEmpty
            ? quote.mediaPath
            : quote.remotePhotoId,
        kind: ChatMessageKind.photo,
        side: ChatSenderSide.merchant,
        at: DateTime.fromMillisecondsSinceEpoch(0),
        mediaPath: quote.mediaPath,
        remotePhotoId: quote.remotePhotoId,
      ),
      width: size,
      height: size,
      radius: 6,
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.suggested});

  final ChatProductRef product;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatProductThumb(product: product, size: 42, radius: 8),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggested)
                  Text(
                    'Suggested',
                    style: AppTextStyles.caption(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
                Text(product.name, style: AppTextStyles.label(fontSize: 13)),
                Text(
                  product.detail,
                  style: AppTextStyles.caption(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BasketGrid extends StatelessWidget {
  const _BasketGrid({required this.message, this.onProductTap});

  final ChatMessage message;
  final ValueChanged<ChatProductRef>? onProductTap;

  @override
  Widget build(BuildContext context) {
    final products = message.products.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final product in products)
            GestureDetector(
              onTap: onProductTap == null ? null : () => onProductTap!(product),
              child: ChatProductThumb(product: product, size: 72, radius: 8),
            ),
        ],
      ),
    );
  }
}

class ChatStatusLine extends StatelessWidget {
  const ChatStatusLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption(fontSize: 12, color: chatMuted),
      ),
    );
  }
}

class ChatDayChip extends StatelessWidget {
  const ChatDayChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.isNight ? const Color(0xFF182229) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: chatMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizedChatPhoto extends StatefulWidget {
  const _SizedChatPhoto({
    required this.message,
    required this.maxWidth,
    required this.showTime,
    required this.time,
    this.receipt,
    this.showBadges = false,
  });

  final ChatMessage message;
  final double maxWidth;
  final bool showTime;
  final String time;
  final ChatReceipt? receipt;
  final bool showBadges;

  @override
  State<_SizedChatPhoto> createState() => _SizedChatPhotoState();
}

class _SizedChatPhotoState extends State<_SizedChatPhoto> {
  Uint8List? _bytes;
  Size? _pixels;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _chatPhotoBytesOf(widget.message);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _failed = true);
        return;
      }
      final key = _chatPhotoKey(widget.message);
      var size = key.isEmpty ? null : _chatPhotoPixelSize[key];
      if (size == null) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        size = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
        codec.dispose();
        if (key.isNotEmpty) _chatPhotoPixelSize[key] = size;
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _pixels = size;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fitted = _pixels == null
        ? Size(widget.maxWidth, widget.maxWidth * 0.72)
        : _fitPhoto(_pixels!, widget.maxWidth);
    final bytes = _bytes;
    return SizedBox(
      width: fitted.width,
      height: fitted.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes == null)
            _photoStandIn(
              widget.message,
              width: fitted.width,
              height: fitted.height,
              waiting: !_failed,
            )
          else
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          if (widget.showBadges && widget.message.starred)
            const Positioned(
              top: 6,
              left: 6,
              child: Icon(Icons.star_rounded, size: 18, color: chatTeamNote),
            ),
          if (widget.showBadges && widget.message.teamOnly)
            Positioned(
              top: 6,
              left: widget.message.starred ? 28 : 6,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x99000000),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.lock_rounded, size: 12, color: chatTeamNote),
                ),
              ),
            ),
          if (widget.showTime) ...[
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 2)],
                    ),
                  ),
                  if (widget.receipt != null) ...[
                    const SizedBox(width: 3),
                    ChatReceiptTicks(
                      receipt: widget.receipt,
                      size: 16,
                      idleColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Size _fitPhoto(Size pixels, double maxWidth) {
  const maxHeight = 360.0;
  final width = math.max(pixels.width, 1.0);
  final height = math.max(pixels.height, 1.0);
  final scale = math.min(maxWidth / width, maxHeight / height);
  return Size(width * scale, height * scale);
}

void openChatPhoto(BuildContext context, ChatMessage message) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, animation, _) {
        return FadeTransition(
          opacity: animation,
          child: _ChatPhotoPage(message: message),
        );
      },
    ),
  );
}

class _ChatPhotoPage extends StatefulWidget {
  const _ChatPhotoPage({required this.message});

  final ChatMessage message;

  @override
  State<_ChatPhotoPage> createState() => _ChatPhotoPageState();
}

class _ChatPhotoPageState extends State<_ChatPhotoPage> {
  final TransformationController _zoom = TransformationController();
  Uint8List? _bytes;
  bool _failed = false;
  Offset _doubleTap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await _chatPhotoBytesOf(widget.message);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _failed = bytes == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.05) {
      _zoom.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final x = -_doubleTap.dx * (scale - 1);
    final y = -_doubleTap.dy * (scale - 1);
    _zoom.value = Matrix4.identity()
      ..translate(x, y)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: bytes == null
                ? Center(
                    child: _failed
                        ? const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  )
                : GestureDetector(
                    onDoubleTapDown: (details) {
                      _doubleTap = details.localPosition;
                    },
                    onDoubleTap: _toggleZoom,
                    child: InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 5,
                      child: SizedBox.expand(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 4,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPhotoView extends StatelessWidget {
  const ChatPhotoView({
    super.key,
    required this.message,
    this.width = 220,
    this.height = 160,
    this.radius = 12,
  });

  final ChatMessage message;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = message.mediaPath.trim();
    final Widget image;
    if (path.isNotEmpty && File(path).existsSync()) {
      image = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } else if (message.remotePhotoId.trim().isNotEmpty) {
      image = _RemoteChatPhoto(
        photoId: message.remotePhotoId.trim(),
        width: width,
        height: height,
      );
    } else {
      image = _photoStandIn(message, width: width, height: height);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

final _chatPhotoBytes = <String, Uint8List>{};
final _chatPhotoPixelSize = <String, Size>{};

String _chatPhotoKey(ChatMessage message) {
  final id = message.remotePhotoId.trim();
  if (id.isNotEmpty) return id;
  return message.mediaPath.trim();
}

Future<Uint8List?> _chatPhotoBytesOf(ChatMessage message) async {
  final key = _chatPhotoKey(message);
  if (key.isNotEmpty) {
    final cached = _chatPhotoBytes[key];
    if (cached != null) return cached;
  }
  final path = message.mediaPath.trim();
  if (path.isNotEmpty && File(path).existsSync()) {
    final data = await File(path).readAsBytes();
    if (key.isNotEmpty) _chatPhotoBytes[key] = data;
    return data;
  }
  final id = message.remotePhotoId.trim();
  if (id.isEmpty) return null;
  final bytes = await ServiceLocator.get<ChatRepository>().downloadPhoto(id);
  final data = Uint8List.fromList(bytes);
  _chatPhotoBytes[id] = data;
  return data;
}

class _RemoteChatPhoto extends StatefulWidget {
  const _RemoteChatPhoto({
    required this.photoId,
    required this.width,
    required this.height,
  });

  final String photoId;
  final double width;
  final double height;

  @override
  State<_RemoteChatPhoto> createState() => _RemoteChatPhotoState();
}

class _RemoteChatPhotoState extends State<_RemoteChatPhoto> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final cached = _chatPhotoBytes[widget.photoId];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await ServiceLocator.get<ChatRepository>().downloadPhoto(
        widget.photoId,
      );
      if (!mounted) return;
      final data = Uint8List.fromList(bytes);
      _chatPhotoBytes[widget.photoId] = data;
      setState(() => _bytes = data);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return _photoStandIn(
        null,
        width: widget.width,
        height: widget.height,
        waiting: !_failed,
      );
    }
    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}

Widget _photoStandIn(
  ChatMessage? message, {
  required double width,
  required double height,
  bool waiting = false,
}) {
  final color = message == null || message.mediaColorValue == 0
      ? const Color(0xFFC4A265)
      : Color(message.mediaColorValue);
  return Container(
    width: width,
    height: height,
    color: color,
    alignment: Alignment.center,
    child: waiting
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            Icons.image_outlined,
            color: Colors.white.withValues(alpha: 0.9),
            size: height > 80 ? 36 : 22,
          ),
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 22, color: chatInk),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(fontSize: 14, color: chatInk),
            ),
          ),
        ],
      ),
    );
  }
}
