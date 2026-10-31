import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/guide.dart';
import '../../services/media_store.dart';
import 'photo_thumb.dart';

/// 照片地图徽标：真实文件缩略图圆形徽标；
/// 缺文件回退渐变占位。供照片墙页与攻略地图页共用。
class PhotoMapBadge extends StatelessWidget {
  const PhotoMapBadge({super.key, required this.photo});

  final PhotoItem photo;

  @override
  Widget build(BuildContext context) {
    // 视频：原件绝不当图片解码 —— 只认首帧缩略；缺缩略走渐变占位。
    // 缩略命中时中心叠 ▶ 角标。
    // 锁定配对统一走 thumbBinding（条目自带「文件名↔缩略图名」）。
    final rel = photo.thumbBinding;
    if (photo.isVideo) {
      return Stack(
        children: [
          if (rel.isNotEmpty)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: _LoadedImage(rel: rel),
              ),
            )
          else
            PhotoThumb(
              gradientIndex: photo.gradientIndex,
              circle: true,
              width: 46,
              height: 46,
              iconSize: 20,
            ),
          const Positioned.fill(
            child: Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 20,
                  shadows: [Shadow(blurRadius: 4)]),
            ),
          ),
        ],
      );
    }
    if (rel.isEmpty) {
      return PhotoThumb(
        gradientIndex: photo.gradientIndex,
        circle: true,
        width: 46,
        height: 46,
        iconSize: 20,
      );
    }
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: _LoadedImage(rel: rel),
      ),
    );
  }
}

/// 相对路径取字节渲染（MediaCache 复用；miss/失败给占位图标）
class _LoadedImage extends StatelessWidget {
  const _LoadedImage({required this.rel});

  final String rel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: MediaStore.load(rel),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return const _FallbackBox();
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const _FallbackBox(),
        );
      },
    );
  }
}

class _FallbackBox extends StatelessWidget {
  const _FallbackBox();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE6DED4),
        alignment: Alignment.center,
        child: const Icon(Icons.photo, size: 18, color: Colors.white70),
      );
}
