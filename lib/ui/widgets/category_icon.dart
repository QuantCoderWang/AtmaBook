import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/media_store.dart';

/// 分类图标显示：分类配置了自定义图片（[MarkerCategory.image]，
/// 来自设置页「分类管理 → 上传图片图标」）时**圆裁等尺寸**显示图片，
/// 否则回退内置 [MarkerCategory.icon]。
///
/// 与 [PinWidget] 的图片渲染同口径（圆 + BoxFit.cover + 同尺寸盒），
/// 保证「图片替代 Pin 图标」不产生大小差；全部分类图标读取点
/// （图例 / 标记抽屉 / 标记编辑 / 笔记 / 详情弹层 / 设置卡）
/// 统一使用组件，避免「地图换了图、其他界面仍是内置图标」的分叉。
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.cat,
    required this.iconSize,
    this.imageBox,
    this.color,
  });

  final MarkerCategory cat;

  /// 内置图标显示尺寸（无图片时的分支）
  final double iconSize;

  /// 自定义图片显示盒边长；默认与 [iconSize] 相同。
  /// 在彩色圆容器里用时应给容器直径（如设置卡 30 / 抽屉 34），
  /// 使图片铺满圆而非露出底色。
  final double? imageBox;

  /// 仅内置图标分支用（白色 / 分类色 / 选中态等）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rel = cat.image;
    if (rel == null) {
      return Icon(cat.icon, size: iconSize, color: color ?? cat.color);
    }
    final box = imageBox ?? iconSize;
    final cached = MediaStore.cacheBytes(rel);
    if (cached != null) return _img(cached, box);
    return FutureBuilder<Uint8List?>(
      future: MediaStore.load(rel),
      builder: (context, snap) => snap.data != null
          ? _img(snap.data!, box)
          : Icon(cat.icon, size: iconSize, color: color ?? cat.color),
    );
  }

  Widget _img(Uint8List bytes, double box) => ClipOval(
        child: SizedBox(
          width: box,
          height: box,
          child: Image.memory(bytes,
              fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );
}
