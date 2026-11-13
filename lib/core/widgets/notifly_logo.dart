import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// NotiFly Logo Widget
/// Renders the official NotiFly Bell + Chat Bubble + Motion Waves logo at any scale.
class NotiFlyLogo extends StatelessWidget {
  const NotiFlyLogo({
    super.key,
    this.size = 120,
    this.showText = true,
    this.color = AppColors.messengerBlue,
    this.textColor,
  });

  final double size;
  final bool showText;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? color;
    final iconSize = showText ? size * 0.72 : size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(
            painter: _NotiFlyLogoPainter(color: color),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.08),
          Text(
            'Notifly',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: effectiveTextColor,
              letterSpacing: -0.5,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ],
    );
  }
}

/// Vector Painter for the NotiFly Bell + Chat Bubble + Motion Waves logo
class _NotiFlyLogoPainter extends CustomPainter {
  _NotiFlyLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // ── 1. Chat Bubble (Top-Right Behind Bell) ─────────────────────────
    final bubbleCenter = Offset(w * 0.62, h * 0.32);
    final bubbleRadius = w * 0.24;
    canvas.drawCircle(bubbleCenter, bubbleRadius, paint);

    // Chat bubble tail (bottom-right)
    final tailPath = Path()
      ..moveTo(w * 0.68, h * 0.48)
      ..lineTo(w * 0.74, h * 0.58)
      ..lineTo(w * 0.58, h * 0.52)
      ..close();
    canvas.drawPath(tailPath, paint);

    // ── 2. Notification Bell Body ─────────────────────────────────────
    final bellPath = Path();

    // Top loop / handle
    final loopCenter = Offset(w * 0.40, h * 0.12);
    canvas.drawCircle(loopCenter, w * 0.05, paint);

    // Bell dome & body
    bellPath.moveTo(w * 0.40, h * 0.16);
    // Left arch down to flare
    bellPath.cubicTo(
      w * 0.22, h * 0.22,
      w * 0.18, h * 0.42,
      w * 0.16, h * 0.58,
    );
    // Bottom left curve outwards
    bellPath.quadraticBezierTo(
      w * 0.14, h * 0.64,
      w * 0.24, h * 0.68,
    );
    // Bottom flare across to right
    bellPath.cubicTo(
      w * 0.40, h * 0.72,
      w * 0.56, h * 0.68,
      w * 0.64, h * 0.58,
    );
    // Right arch up to top
    bellPath.cubicTo(
      w * 0.58, h * 0.42,
      w * 0.52, h * 0.22,
      w * 0.40, h * 0.16,
    );
    bellPath.close();

    canvas.drawPath(bellPath, paint);

    // Cutout highlight curve on inner left of bell (white accent)
    final highlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final highlightPath = Path();
    highlightPath.moveTo(w * 0.34, h * 0.28);
    highlightPath.cubicTo(
      w * 0.27, h * 0.36,
      w * 0.25, h * 0.48,
      w * 0.28, h * 0.56,
    );
    canvas.drawPath(highlightPath, highlightPaint);

    // ── 3. Bell Clapper (Bottom Center Circle) ───────────────────────
    final clapperCenter = Offset(w * 0.39, h * 0.75);
    canvas.drawCircle(clapperCenter, w * 0.055, paint);

    // ── 4. Sweeping Motion Waves (Under Rim) ──────────────────────────
    final wavePath = Path();
    wavePath.moveTo(w * 0.18, h * 0.60);
    wavePath.cubicTo(
      w * 0.30, h * 0.74,
      w * 0.55, h * 0.82,
      w * 0.82, h * 0.62,
    );
    wavePath.cubicTo(
      w * 0.72, h * 0.88,
      w * 0.42, h * 0.88,
      w * 0.18, h * 0.60,
    );
    wavePath.close();
    canvas.drawPath(wavePath, paint);

    // Second lower wave line
    final wavePath2 = Path();
    wavePath2.moveTo(w * 0.35, h * 0.74);
    wavePath2.cubicTo(
      w * 0.50, h * 0.88,
      w * 0.68, h * 0.88,
      w * 0.80, h * 0.76,
    );
    wavePath2.cubicTo(
      w * 0.68, h * 0.94,
      w * 0.48, h * 0.92,
      w * 0.35, h * 0.74,
    );
    wavePath2.close();
    canvas.drawPath(wavePath2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
