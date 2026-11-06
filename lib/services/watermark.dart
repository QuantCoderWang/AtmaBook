import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 分享图片水印合成器。
/// 缩放和 JPEG 编码交给 `image` 包（纯 Dart，任何 isolate 都能跑）；
/// 中文水印用 Flutter 引擎的 [TextPainter] 画
/// （image 包的位图字体画不了中文）：
/// 半透明白字 + 黑描边，落在左下角，字号随图宽自适应，输出不可逆。
class WatermarkComposer {
  WatermarkComposer._();

  /// 单张处理：[maxSide] 限长边像素，[quality] 为 JPEG 质量（72 副本 / 70 缩略）。
  /// [text] 为空串时跳过水印（仅缩放）——测试与「不加水印」的代码路径共用。
  static Future<Uint8List?> compose({
    required Uint8List srcBytes,
    required String text,
    required int maxSide,
    required int quality,
  }) async {
    try {
      // 缩放（image 包）
      final decoded = img.decodeImage(srcBytes);
      if (decoded == null) return null;
      var out = decoded;
      final longest = math.max(out.width, out.height);
      if (longest > maxSide) {
        final scale = maxSide / longest;
        out = img.copyResize(
          out,
          width: (out.width * scale).round(),
          height: (out.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      // 经无损 PNG 中转到引擎画布（image 包不能直接喂 ui.Image）
      final png = Uint8List.fromList(img.encodePng(out));
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 合成水印（引擎画布）
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());
      if (text.isNotEmpty) {
        paintTiledWatermark(canvas, image.width.toDouble(),
            image.height.toDouble(), text);
      }
      final picture = recorder.endRecording();
      final composed = await picture.toImage(image.width, image.height);

      // 引擎画布 → JPEG（rawRgba 回填 image 包编码）
      final data = await composed.toByteData(
          format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final rgba = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: data.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final jpg = Uint8List.fromList(img.encodeJpg(rgba, quality: quality));

      image.dispose();
      composed.dispose();
      return jpg;
    } catch (e) {
      debugPrint('水印合成失败（保留原图不中断导出）：$e');
      return null;
    }
  }

  /// 整版透明水印 PNG（视频链路使用）：
  /// 和照片同一套 45° 平铺算法画在透明画布上，编码为 PNG（保留 alpha）——
  /// 由 ffmpeg `overlay` 一次性叠加到转码后的每一帧（中文由引擎绘制，无字体痛点）。
  /// 返回 PNG 字节；失败返回 null（调用方跳过水印仅转码）。
  static Future<Uint8List?> tiledOverlayPng({
    required int width,
    required int height,
    required String text,
  }) async {
    if (text.isEmpty || width <= 0 || height <= 0) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      paintTiledWatermark(canvas, width.toDouble(), height.toDouble(), text);
      final picture = recorder.endRecording();
      final composed = await picture.toImage(width, height);
      final data = await composed.toByteData(
          format: ui.ImageByteFormat.rawRgba);
      composed.dispose();
      if (data == null) return null;
      final rgba = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: data.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return Uint8List.fromList(img.encodePng(rgba));
    } catch (e) {
      debugPrint('水印叠加 PNG 生成失败：$e');
      return null;
    }
  }

  /// 45° 平铺水印公共绘制（照片/视频共用同一算法与参数）：
  /// 几个参数约定：
  /// 1、字号 = 画幅短边 × 10%（防滥用要求的显著字号）；
  /// 2、网格基线密度由画幅（对角线 × 0.16）决定，文字加宽时间距随之加宽防重贴；
  /// 3、透明度 白 22% / 黑描边 22%；
  /// 4、覆盖范围 = 旋转 45° 后包围盒半径 (w+h)·√2/4，边缘零漏铺。
  static void paintTiledWatermark(
      ui.Canvas canvas, double w, double h, String text) {
    final diag = math.sqrt(w * w + h * h);
    final short = math.min(w, h);

    final fontSize = (short * 0.10).clamp(10.0, 160.0).toDouble();
    TextPainter layoutAt(double fs) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: const Color(0x38FFFFFF), // 白 22%
              fontSize: fs,
              fontWeight: FontWeight.w700,
              shadows: [
                const Shadow(
                  color: Color(0x38000000), // 黑 22% 描边感
                  offset: Offset(1.5, 1.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final tp = layoutAt(fontSize);

    final baseCell = diag * 0.16;
    final stepX = math.max(baseCell, tp.width * 1.6);
    final stepY = math.max(baseCell * 2.6, tp.height * 4.0);
    final reach = (w + h) * math.sqrt2 / 4;
    final cols = (reach / stepX).ceil() + 1;
    final rows = (reach / stepY).ceil() + 1;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-math.pi / 4); // -45°：左低右高的阅读向斜线
    for (var r = -rows; r <= rows; r++) {
      for (var c = -cols; c <= cols; c++) {
        final shiftX = r.isOdd ? stepX / 2 : 0.0;
        tp.paint(
          canvas,
          ui.Offset(-reach + c * stepX + shiftX, -reach + r * stepY),
        );
      }
    }
    canvas.restore();
  }
}
