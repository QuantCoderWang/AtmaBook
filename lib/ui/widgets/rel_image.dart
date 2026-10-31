import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/media_store.dart';

/// 相对路径图片（`pics/...`）：内存缓存同步优先，miss 时异步补载。
/// 用在标记详情缩略图、编辑页照片与自定义 Pin 图标。
class RelImage extends StatefulWidget {
  const RelImage({
    super.key,
    required this.rel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String rel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  State<RelImage> createState() => _RelImageState();
}

class _RelImageState extends State<RelImage> {
  @override
  void initState() {
    super.initState();
    if (MediaStore.cacheBytes(widget.rel) == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await MediaStore.load(widget.rel);
    if (bytes != null && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RelImage old) {
    super.didUpdateWidget(old);
    if (old.rel != widget.rel) {
      if (MediaStore.cacheBytes(widget.rel) == null) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = MediaStore.cacheBytes(widget.rel);
    Widget image = bytes != null
        ? Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          )
        : (widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              alignment: Alignment.center,
              color: const Color(0xFFEFE9DC),
              child: const Icon(Icons.image_outlined,
                  size: 20, color: Colors.black26),
            ));
    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}

/// 字节图（已缓存图片直用的轻量包装）
class BytesImage extends StatelessWidget {
  const BytesImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
    );
  }
}
