import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'ffmpeg_runner.dart';
import 'watermark.dart';

/// 分享导出视频转码器：
/// 原视频（最高 4K）→ ≤720p H.264 + 斜向平铺水印 → mp4 字节入 `.tgshare`。
/// - 降质：libx264 CRF30 + veryfast，短边压至 720（横 `1280×720` / 竖 `720×1280`）；
/// - 水印：Dart `WatermarkComposer.tiledOverlayPng` 生成整版透明水印 PNG
///   （与照片水印逐像素同源的 45° 平铺算法，中文由引擎绘制规避 ffmpeg 字体痛点），
///   ffmpeg 单行 `overlay` 叠到每一帧，烧录后不可逆；
/// - 音频 aac 96k；`+faststart` 流式播放友好；
/// - 输出文件不落到用户存储（临时工作区 pics/videos/tmp_ 前缀，读完就删）。
class VideoTranscoder {
  VideoTranscoder._();

  /// 目标尺寸规则（横屏高 720、竖屏宽 720、正方亦然；奇数边界交 ffmpeg -2 对齐）。
  /// 纯函数，测试直接覆盖。
  static (int, int) targetSizeFor(int w, int h) {
    if (w <= 0 || h <= 0) return (1280, 720);
    // 短边压到 720：横屏 h=720（宽自适应 ≤1280 量级），竖屏 w=720
    return h >= w ? (720, -2) : (-2, 720);
  }

  /// 转码 + 烧录水印 → 返回 mp4 字节；失败/取消返回 null。
  /// [onProgress] 传入 0..1 线性进度（按时长折算）；[isCancelled] 中途 FK 杀进程。
  static Future<Uint8List?> transcode({
    required String absInputPath,
    required String watermarkText,
    void Function(double frac)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!FFmpegRunner.available) return null;
    await FFmpegRunner.ensure();
    final probe = await FFmpegRunner.probeDurationMs(absInputPath);
    final size = await FFmpegRunner.probeVideoSize(absInputPath);
    final (tw, th) =
        size != null ? targetSizeFor(size.$1, size.$2) : (1280, 720);

    // 水印整版 PNG（按目标分辨率；失败就跳过水印，只转码）
    final overlayBytes =
        await WatermarkComposer.tiledOverlayPng(
            width: tw > 0 ? tw : 1280, height: th > 0 ? th : 720, text: watermarkText);

    final overlayFile =
        await FFmpegRunner.tempFileInVideosDir('tmp_wm', '.png');
    final outFile = await FFmpegRunner.tempFileInVideosDir('tmp_out', '.mp4');
    Process? proc;
    try {
      if (overlayBytes != null) {
        await overlayFile.writeAsBytes(overlayBytes, flush: true);
      }

      // 滤镜图：先缩放 → 叠水印（有水印叠输入 1；无水印直接映射）
      final args = <String>[
        '-y', '-v', 'error',
        '-hwaccel', 'auto',
        '-i', absInputPath,
      ];
      if (overlayBytes != null) args.addAll(['-i', overlayFile.path]);
      args.addAll([
        '-filter_complex',
        overlayBytes != null
            ? '[0:v]scale=$tw:$th[v0];[v0][1:v]overlay=0:0[v]'
            : '[0:v]scale=$tw:$th[v]',
        '-map', '[v]',
        '-map', '0:a?',
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '30',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        // 死锁规避：此构建下原生 AAC 编码器与 libx264 并发运行
        // 会互相等待（无 -aac_coder fast 时联合编码无法收敛，实测
        // 2.45s 视频挂 10 分钟+）；fast 模式绕过，输出仍为标准 aac。
        '-aac_coder', 'fast', '-b:a', '96k',
        '-movflags', '+faststart',
        '-f', 'mp4',
        '-progress', 'pipe:1', '-nostats',
        outFile.path,
      ]);

      proc = await Process.start(FFmpegRunner.ffmpegExe!, args);
      // 进度行解析：`out_time_ms=1234567`（微秒）；总时长已知 → frac
      final stdoutSub = proc.stdout
          .transform(
              const Utf8Codec(allowMalformed: true).decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (!line.startsWith('out_time_ms=')) return;
        final us = int.tryParse(line.substring(12));
        if (us == null || probe == null || probe <= 0) return;
        onProgress?.call((us / 1000.0 / probe).clamp(0.0, 1.0));
      });
      // stderr 持续排空防阻塞
      proc.stderr.listen((_) {});

      var cancelled = false;
      final timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (isCancelled?.call() ?? false) {
          cancelled = true;
          proc?.kill();
        }
      });
      await proc.exitCode;
      timer.cancel();
      unawaited(stdoutSub.cancel());

      if (cancelled) return null;
      final f = File(outFile.path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    } finally {
      try {
        proc?.kill();
      } catch (_) {}
      for (final f in [overlayFile, outFile]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }
}
