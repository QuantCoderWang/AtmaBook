import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// 通用占位照片（未接入真实图片前使用渐变色块）
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.gradientIndex,
    this.width,
    this.height,
    this.radius = 12,
    this.circle = false,
    this.iconSize = 26,
    this.onTap,
  });

  final int gradientIndex;
  final double? width;
  final double? height;
  final double radius;
  final bool circle;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TravelPalette.photoGradients[
        gradientIndex % TravelPalette.photoGradients.length];
    final shape = BoxDecoration(
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    );
    final body = DecoratedBox(
      decoration: shape.copyWith(boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ]),
      child: Icon(Icons.photo, color: Colors.white70, size: iconSize),
    );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: body,
      ),
    );
  }
}
