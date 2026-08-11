import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';

class JewelFlowLogo extends StatelessWidget {
  const JewelFlowLogo({
    super.key,
    this.size = 88,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          // BoxShadow(
          //   color: AppColors.primary.withValues(alpha: 0.28),
          //   blurRadius: 24,
          //   offset: const Offset(0, 10),
          // ),
        ],
      ),
      child: CustomPaint(
        painter: _DiamondPainter(),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.28;
    final h = size.height * 0.34;

    final path = Path()
      ..moveTo(cx, cy - h)
      ..lineTo(cx + w, cy - h * 0.15)
      ..lineTo(cx, cy + h)
      ..lineTo(cx - w, cy - h * 0.15)
      ..close();

    canvas.drawPath(path, paint);

    final mid = Path()
      ..moveTo(cx - w, cy - h * 0.15)
      ..lineTo(cx + w, cy - h * 0.15)
      ..moveTo(cx, cy - h)
      ..lineTo(cx, cy - h * 0.15)
      ..moveTo(cx - w * 0.45, cy - h * 0.15)
      ..lineTo(cx, cy + h)
      ..moveTo(cx + w * 0.45, cy - h * 0.15)
      ..lineTo(cx, cy + h);

    canvas.drawPath(mid, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
