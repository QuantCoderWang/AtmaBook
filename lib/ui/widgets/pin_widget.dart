import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// 地点标记 Pin：
/// - 图标式（默认）：圆头 + 分类图形（或用户自定义图片）
/// - 彩色大头针（simplified = true）：无图形纯色彩，用颜色区分类型
/// 其余能力通用：必去星标 / 片区色环 / 选中态
class PinWidget extends StatelessWidget {
  const PinWidget({
    super.key,
    required this.color,
    this.icon,
    this.iconBytes,
    this.size = 40,
    this.mustVisit = false,
    this.selected = false,
    this.ringColor,
    this.simplified = false,
  });

  final Color color;
  final IconData? icon;
  final Uint8List? iconBytes;
  final double size;
  final bool mustVisit;

  /// 片区色环颜色（必去点所属片区）
  final Color? ringColor;
  final bool selected;

  /// 彩色大头针模式（无图形）
  final bool simplified;

  @override
  Widget build(BuildContext context) {
    final double h = size * 1.32;
    final double iw = icon == null || simplified ? 0 : size * 0.46;
    final Widget body = SizedBox(
      width: size,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PinPainter(
                color: color,
                ringColor: ringColor,
                selected: selected,
                simplified: simplified,
              ),
            ),
          ),
          if (iw > 0)
            Positioned(
              left: (size - iw) / 2,
              top: (size - iw) / 2,
              child: iconBytes != null
                  ? Container(
                      width: iw,
                      height: iw,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: MemoryImage(iconBytes!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Icon(icon ?? Icons.place,
                      color: Colors.white, size: iw),
            ),
          if (mustVisit)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: size * 0.44,
                height: size * 0.44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Icon(Icons.star, size: size * 0.28, color: Colors.white),
              ),
            ),
        ],
      ),
    );
    return selected ? Transform.scale(scale: 1.14, child: body) : body;
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({
    required this.color,
    this.ringColor,
    this.selected = false,
    this.simplified = false,
  });

  final Color color;
  final Color? ringColor;
  final bool selected;
  final bool simplified;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset ball = Offset(w / 2, simplified ? w * 0.52 : w / 2);
    final double r = simplified ? w * 0.46 : w / 2 - 3;
    final Offset tip = Offset(w / 2, h - 1);

    // 针尾三角：从尖角到球体两条切线
    final a = math.asin(math.min(0.9, r / (tip.dy - ball.dy)));
    final dir = Offset(0, 1);
    final p1 = _rot(dir, a) * r * 0.96 + ball;
    final p2 = _rot(dir, -a) * r * 0.96 + ball;
    final tail = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);

    // 片区色环（画在球体下层）
    if (ringColor != null) {
      canvas.drawCircle(
        ball,
        r + 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ringColor!,
      );
    }

    canvas.drawCircle(ball, r, Paint()..color = color);

    // 白描边（选中态加粗）
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 1.8
      ..color = Colors.white;
    canvas.drawPath(tail, stroke);
    canvas.drawCircle(ball, r, stroke);

    // 彩色大头针模式：中心白色小点，无图形
    if (simplified) {
      canvas.drawCircle(
        ball,
        r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  Offset _rot(Offset v, double ang) => Offset(
        v.dx * math.cos(ang) - v.dy * math.sin(ang),
        v.dx * math.sin(ang) + v.dy * math.cos(ang),
      );

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.selected != selected ||
      oldDelegate.simplified != simplified;
}
