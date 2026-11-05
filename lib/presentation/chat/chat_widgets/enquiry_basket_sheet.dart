import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

const _basketQuestions = <String>[
  'Are these available?',
  'Making charges?',
  'Share weight?',
];

/// Enquiry basket: selected photos, suggested questions, and one message.
/// Each photo becomes its own discussion after send.
Future<void> showEnquiryBasketSheet({
  required BuildContext context,
  required List<ChatProductRef> products,
  required ValueChanged<String> onRemove,
  required VoidCallback onAddMore,
  required void Function(String text, List<ChatProductRef> products) onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (sheetContext) {
      return _EnquiryBasketSheet(
        products: products,
        onRemove: onRemove,
        onAddMore: () {
          Navigator.of(sheetContext).pop();
          onAddMore();
        },
        onSend: (text, remaining) {
          Navigator.of(sheetContext).pop();
          onSend(text, remaining);
        },
      );
    },
  );
}

class _EnquiryBasketSheet extends StatefulWidget {
  const _EnquiryBasketSheet({
    required this.products,
    required this.onRemove,
    required this.onAddMore,
    required this.onSend,
  });

  final List<ChatProductRef> products;
  final ValueChanged<String> onRemove;
  final VoidCallback onAddMore;
  final void Function(String text, List<ChatProductRef> products) onSend;

  @override
  State<_EnquiryBasketSheet> createState() => _EnquiryBasketSheetState();
}

class _EnquiryBasketSheetState extends State<_EnquiryBasketSheet> {
  late final List<ChatProductRef> _products = List.of(widget.products);
  late final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _remove(ChatProductRef product) {
    setState(() => _products.removeWhere((item) => item.id == product.id));
    widget.onRemove(product.id);
    if (_products.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final count = _products.length;
    final canSend = _text.text.trim().isNotEmpty && count > 0;
    final night = AppColors.isNight;
    final card = night ? AppColors.grey850 : AppColors.surface;
    final field = night ? AppColors.grey900 : AppColors.surfaceSecondary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        (keyboard > 0 ? keyboard : bottom) + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count product${count == 1 ? '' : 's'}',
                          style: AppTextStyles.label(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final product in _products)
                              _RemovableThumb(
                                product: product,
                                onRemove: () => _remove(product),
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
                      SizedBox(
                        width: 110,
                        child: Text(
                          'Each gets its own discussion',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: field,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: widget.onAddMore,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: AppColors.textPrimary,
                                ),
                                Text(
                                  'Add',
                                  style: AppTextStyles.caption(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _basketQuestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final phrase = _basketQuestions[index];
                return ActionChip(
                  label: Text(
                    phrase,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: card,
                  side: BorderSide(color: AppColors.border),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _text.text = phrase;
                    _text.selection = TextSelection.collapsed(
                      offset: phrase.length,
                    );
                    _focus.requestFocus();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.body(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: AppTextStyles.hint(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: card,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: canSend ? Colors.white : AppColors.surfaceSecondary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap:
                      canSend
                          ? () {
                            HapticFeedback.selectionClick();
                            widget.onSend(
                              _text.text.trim(),
                              List.of(_products),
                            );
                          }
                          : null,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: canSend ? AppColors.grey900 : AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemovableThumb extends StatelessWidget {
  const _RemovableThumb({required this.product, required this.onRemove});

  final ChatProductRef product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChatProductThumb(product: product, size: 48, radius: 8),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.grey900,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
