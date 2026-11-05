import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_models.dart';

const chatReadTick = Color(0xFF3B9BE8);
const chatSwitchOn = Color(0xFF16A34A);

/// Thread chrome uses the app palette. Night stays graphite; day uses the
/// Telegram blue only for your bubble and the send button.
Color get chatWallpaper => AppColors.scaffold;

Color get chatBar => AppColors.surface;

Color get chatIncoming =>
    AppColors.isNight ? AppColors.surfaceSecondary : AppColors.surface;

Color get chatSenderName =>
    AppColors.isNight ? const Color(0xFF8FB9AE) : const Color(0xFF2E7D6B);

Color get chatField =>
    AppColors.isNight ? AppColors.surfaceSecondary : AppColors.scaffold;

Color get chatInk => AppColors.textPrimary;

Color get chatMuted => AppColors.textSecondary;

Color get chatSend => AppColors.isNight ? AppColors.accent : AppColors.primary;

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
  const ChatReceiptTicks({super.key, required this.receipt, this.size = 14});

  final ChatReceipt? receipt;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (receipt == null) return const SizedBox.shrink();
    final read = receipt == ChatReceipt.read;
    final color = read ? chatReadTick : AppColors.textHint;
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
                      color: Colors.white.withValues(
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
    this.onProductTap,
    this.senderLabel,
    this.alignRight,
  });

  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;
  final ValueChanged<ChatProductRef>? onProductTap;
  final String? senderLabel;

  /// Right side is your own bubble. Defaults to store-side messages.
  final bool? alignRight;

  @override
  Widget build(BuildContext context) {
    final mineSide = alignRight ?? message.side == ChatSenderSide.merchant;
    final team = message.teamOnly;
    final onWhite = mineSide && !team;
    final textColor = onWhite ? const Color(0xFF111111) : chatInk;
    final timeColor = onWhite ? const Color(0xFF667781) : chatMuted;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final label = senderLabel?.trim() ?? '';
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              team
                  ? (AppColors.isNight
                      ? const Color(0xFF241F14)
                      : const Color(0xFFFFF8EC))
                  : (onWhite ? Colors.white : _otherBubble()),
          borderRadius: BorderRadius.circular(18),
          border:
              team || onWhite || AppColors.isNight
                  ? null
                  : Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: textColor),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (team)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: chatTeamNote,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Only your team',
                        style: AppTextStyles.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: chatTeamNote,
                        ),
                      ),
                    ],
                  ),
                ),
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    label,
                    style: AppTextStyles.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: chatSenderName,
                    ),
                  ),
                ),
              if (message.quote != null) _QuoteBlock(quote: message.quote!),
              if (message.kind == ChatMessageKind.basket)
                _BasketGrid(message: message, onProductTap: onProductTap)
              else if (message.products.isNotEmpty)
                _ProductCard(
                  product: message.products.first,
                  suggested: message.suggestedAlternative,
                ),
              if (message.text.trim().isNotEmpty &&
                  message.kind != ChatMessageKind.productShare)
                _MentionText(
                  text: message.text,
                  mentions: message.mentions,
                  style: AppTextStyles.body(
                    fontSize: 15.5,
                    height: 1.25,
                    color: textColor,
                  ),
                ),
              if (message.kind == ChatMessageKind.productShare &&
                  message.text.trim().isNotEmpty &&
                  (message.products.isEmpty ||
                      message.text.trim() != message.products.first.name))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    message.text,
                    style: AppTextStyles.body(
                      fontSize: 15.5,
                      height: 1.25,
                      color: textColor,
                    ),
                  ),
                ),
              const SizedBox(height: 1),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chatClock(message.at),
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        color: timeColor,
                      ),
                    ),
                    if (message.mine) ...[
                      const SizedBox(width: 3),
                      ChatReceiptTicks(receipt: message.receipt, size: 13),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
    final framed = team ? _DashedOutline(child: bubble) : bubble;

    return ChatSwipeToReply(
      onReply: onReply,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(mineSide ? 0 : 6, 1, mineSide ? 6 : 0, 1),
          child: framed,
        ),
      ),
    );
  }
}

class _DashedOutline extends StatelessWidget {
  const _DashedOutline({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedRRectPainter(color: chatTeamNote),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      const Radius.circular(18),
    );
    final path = Path()..addRRect(rrect);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 3.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
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
    final tokens = mentions
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
      final hit = tokens.any((name) => name.toLowerCase() == token.toLowerCase());
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
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.senderLabel,
            style: AppTextStyles.caption(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (quote.product != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                ChatProductThumb(product: quote.product!, size: 28, radius: 6),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quote.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              quote.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(fontSize: 12),
            ),
        ],
      ),
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
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(8),
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
