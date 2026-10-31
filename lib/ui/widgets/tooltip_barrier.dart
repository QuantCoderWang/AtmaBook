import 'package:flutter/material.dart';

/// Tooltip/Slider 锚隔离容器
class TooltipBarrier extends StatelessWidget {
  const TooltipBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, child: child);
}
