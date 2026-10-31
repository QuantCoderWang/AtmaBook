import 'dart:math';

/// 简易 ID 生成：时间戳（base36）+ 随机尾段，避免并发/同毫秒碰撞
String newId(String prefix) {
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rnd =
      (Random.secure().nextInt(1 << 31)).toRadixString(36).padLeft(6, '0');
  return '${prefix}_${ts}_$rnd';
}
