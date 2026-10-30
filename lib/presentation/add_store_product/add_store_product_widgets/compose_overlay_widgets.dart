import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/bulk_upload.dart';

/// Dark frosted disc — keeps toolbar / rail icons readable on any photo.
class ComposeFrostCircle extends StatelessWidget {
  const ComposeFrostCircle({
    super.key,
    required this.child,
    this.size = 40,
    this.filled = false,
    this.emptyRing = false,
  });

  final Widget child;
  final double size;
  final bool filled;
  final bool emptyRing;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // v4 quieter rail: frosted discs, no white rings.
            color:
                filled
                    ? Colors.white
                    : Colors.black.withValues(alpha: emptyRing ? 0.22 : 0.42),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Compact frosted pill for counters / short labels on photo chrome.
class ComposeFrostPill extends StatelessWidget {
  const ComposeFrostPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Rounded panel with a dotted stroke (weight section).
class ComposeDottedPanel extends StatelessWidget {
  const ComposeDottedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ComposeDottedRRectPainter(
        color: Colors.white.withValues(alpha: 0.55),
        radius: radius,
        strokeWidth: 1.2,
        dash: 5,
        gap: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ComposeDottedRRectPainter extends CustomPainter {
  _ComposeDottedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ComposeDottedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

/// Frosted circular rail chip — readable on light or dark photos.
class ComposeRailChip extends StatelessWidget {
  const ComposeRailChip({
    super.key,
    required this.label,
    required this.glyph,
    required this.onTap,
    this.open = false,
    this.empty = false,
    this.glyphWidget,
    this.accent,
  });

  final String label;
  final String glyph;
  final VoidCallback onTap;
  final bool open;
  final bool empty;
  final Widget? glyphWidget;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = open ? Colors.black : Colors.white;
    final Widget disc;
    if (open) {
      disc = ComposeFrostCircle(
        size: 46,
        filled: true,
        child:
            glyphWidget ??
            Text(
              glyph,
              style: AppTextStyles.caption(
                fontSize: glyph.length > 3 ? 11 : 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
      );
    } else if (accent != null) {
      disc = Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child:
            glyphWidget ??
            Text(
              glyph,
              style: AppTextStyles.caption(
                fontSize: glyph.length > 4 ? 10 : 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
      );
    } else {
      disc = ComposeFrostCircle(
        size: 46,
        emptyRing: empty,
        child:
            glyphWidget ??
            Text(
              glyph,
              style: AppTextStyles.caption(
                fontSize: glyph.length > 4 ? 10 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: empty ? 0.7 : 0.92),
              ),
            ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          disc,
          const SizedBox(height: 4),
          SizedBox(
            width: 58,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.72),
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ComposeFlyoutOption extends StatelessWidget {
  const ComposeFlyoutOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ).copyWith(
            decoration: selected ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Colors.white,
            decorationThickness: 1.6,
          ),
        ),
      ),
    );
  }
}

/// Chip on the right; flyout slides in on the left, horizontally centered.
/// Uses [mainAxisSize.min] so empty space does not steal photo pinch gestures.
class ComposeRailSlot extends StatelessWidget {
  const ComposeRailSlot({
    super.key,
    required this.chip,
    required this.open,
    this.flyout,
  });

  final Widget chip;
  final bool open;
  final Widget? flyout;

  @override
  Widget build(BuildContext context) {
    final maxFlyout = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              child:
                  open && flyout != null
                      ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxFlyout),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(open),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, child) {
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(12 * (1 - t), 0),
                                  child: child,
                                ),
                              );
                            },
                            child: flyout,
                          ),
                        ),
                      )
                      : const SizedBox(width: 0, height: 46),
            ),
          ),
          chip,
        ],
      ),
    );
  }
}

/// Dark-surface input theme so compose fields stay readable (not white-on-white).
ThemeData composeOverlayInputTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    brightness: Brightness.dark,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: Color(0x66FFFFFF),
      selectionHandleColor: Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      hintStyle: TextStyle(color: Color(0x99FFFFFF)),
      labelStyle: TextStyle(color: Colors.white70),
      floatingLabelStyle: TextStyle(color: Colors.white70),
      prefixStyle: TextStyle(color: Colors.white70),
      suffixStyle: TextStyle(color: Colors.white70),
    ),
  );
}

class ComposeModePill extends StatelessWidget {
  const ComposeModePill({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onSelected(i),
            child: Text(
              options[i],
              style: AppTextStyles.caption(
                fontSize: 13,
                fontWeight:
                    i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                color:
                    i == selectedIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
              ).copyWith(
                decoration:
                    i == selectedIndex
                        ? TextDecoration.underline
                        : TextDecoration.none,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ComposeWastageStepper extends StatefulWidget {
  const ComposeWastageStepper({
    super.key,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;

  @override
  State<ComposeWastageStepper> createState() => _ComposeWastageStepperState();
}

class _ComposeWastageStepperState extends State<ComposeWastageStepper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.valueText);
  }

  @override
  void didUpdateWidget(covariant ComposeWastageStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueText != widget.valueText &&
        _controller.text != widget.valueText) {
      _controller.text = widget.valueText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, widget.onMinus),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: AppTextStyles.body(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          _stepBtn(Icons.add, widget.onPlus),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class ComposeWeightBlock extends StatelessWidget {
  const ComposeWeightBlock({
    super.key,
    required this.spec,
    required this.grossMinController,
    required this.grossMaxController,
    required this.stoneController,
    required this.showStone,
    required this.onToggleStone,
    required this.onClearStone,
    required this.onWeightMode,
    required this.onGrossChanged,
  });

  final ProductSpec spec;
  final TextEditingController grossMinController;
  final TextEditingController grossMaxController;
  final TextEditingController stoneController;
  final bool showStone;
  final VoidCallback onToggleStone;
  final VoidCallback onClearStone;
  final ValueChanged<WeightMode> onWeightMode;
  final VoidCallback onGrossChanged;

  @override
  Widget build(BuildContext context) {
    final net = spec.netLabel;
    final showNet = showStone && spec.hasDistinctNet;
    final fieldTheme = composeOverlayInputTheme(context);
    return Theme(
      data: fieldTheme,
      child: ComposeDottedPanel(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'WEIGHT',
                style: AppTextStyles.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              ComposeModePill(
                options: const ['Fixed', 'Range'],
                selectedIndex: spec.weightMode == WeightMode.range ? 1 : 0,
                onSelected: (i) {
                  onWeightMode(i == 0 ? WeightMode.fixed : WeightMode.range);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (spec.weightMode == WeightMode.range)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _weightField(grossMinController, hint: 'Min'),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                  child: Text(
                    'to',
                    style: AppTextStyles.caption(color: Colors.white54),
                  ),
                ),
                Expanded(
                  child: _weightField(grossMaxController, hint: 'Max'),
                ),
                const SizedBox(width: 6),
                Text(
                  'g',
                  style: AppTextStyles.body(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _weightField(grossMinController)),
                const SizedBox(width: 6),
                Text(
                  'g',
                  style: AppTextStyles.body(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showNet) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Net $net',
                    style: AppTextStyles.caption(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          if (!showStone)
            GestureDetector(
              onTap: onToggleStone,
              child: Text(
                '+ Stone weight',
                style: AppTextStyles.caption(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stone',
                        style: AppTextStyles.caption(color: Colors.white60),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 56,
                        child: TextField(
                          controller: stoneController,
                          onChanged: (_) => onGrossChanged(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          cursorColor: Colors.white,
                          style: AppTextStyles.body(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            suffixText: 'g',
                            suffixStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onClearStone,
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
        ),
      ),
    );
  }

  Widget _weightField(TextEditingController c, {String? hint}) {
    final empty = c.text.trim().isEmpty;
    return TextField(
      controller: c,
      onChanged: (_) => onGrossChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      cursorColor: Colors.white,
      style: AppTextStyles.title(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        hintText: hint ?? '0',
        hintStyle: AppTextStyles.title(
          fontSize: 34,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: empty ? 0.35 : 0.9),
            width: empty ? 1 : 1.4,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.6),
        ),
      ),
    );
  }
}

class ComposeScopePill extends StatelessWidget {
  const ComposeScopePill({
    super.key,
    required this.applyToAll,
    required this.count,
    required this.onToggle,
  });

  final bool applyToAll;
  final int count;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          applyToAll ? 'All $count' : 'This photo',
          style: AppTextStyles.caption(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Horizontal option row to the left of an open rail chip (grows leftward).
class ComposeFlyoutRow extends StatelessWidget {
  const ComposeFlyoutRow({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

String sizeUnitLabel(SizeUnit unit) {
  switch (unit) {
    case SizeUnit.inch:
      return 'in';
    case SizeUnit.mm:
      return 'mm';
    case SizeUnit.cm:
      return 'cm';
    case SizeUnit.custom:
      return 'custom';
  }
}
