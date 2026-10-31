import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/io/storage_adapter.dart';
import '../core/utils/ids.dart';
import '../data/models/wall_photo.dart';
import 'ffmpeg_runner.dart';
import 'media_store.dart';

/// 视频插入报告
class VideoInsertReport {
  VideoInsertReport();
  int imported = 0;
  int duplicates = 0;
  bool full = false; // 达到相册取样上限
  String? error;

  String get banner =>
      '视频插入：新增 $imported${duplicates > 0 ? ' · 内容重复跳过 $duplicates' : ''}'
      '${full ? '（达到相册取样上限）' : ''}';
}

/// 视频素材化结果（字幕进度名暂借用 name 字段承载原始文件名）
class VideoMaterial {
  VideoMaterial(this.item, this.rel);
  final WallPhoto item;
  final String rel;
}

/// 视频插入服务（只在地理相册插入）：
/// 1. 流式哈希（FNV-1a 采样）+ 流式复制原件到 `pics/videos/v_<哈希>.<ext>`
///    （大文件不整读内存、不进 MediaCache，播放走文件路径）；
/// 2. ffprobe 探时长 + ffmpeg 提取首帧 → ≤512px JPEG 缩略；
///    ffmpeg 不可用自动降级：时长 0 + 渐变占位缩略（不阻塞插入）；
/// 3. 产出**相册账本**条目 `WallPhoto(kind:'video')` —— 无 GPS 入册，
///    与无定位照片同一流程：查看器点选地图**手动补写地理位置**，
///    补写后按就近规则归属攻略 → 攻略地图照片层与照片一致显示。
///    （账本判重 / cap 上限 / 落库由相册页统一收口）
class VideoLedgerService {
  /// 单文件「素材化」：复制原件 + 时长/首帧 → 构建账本条目。
  /// 返回 (item, rel)；出錯返回 (null, 错误文案)。
  Future<(VideoMaterial?, String?)> materialize(String srcPath) async {
    try {
      final src = File(srcPath);
      if (!await src.exists()) return (null, '文件不存在');
      final ext = _extOf(srcPath);

      final root = activeStorage.locationLabel;
      final videoDir = Directory('$root${Platform.pathSeparator}pics'
          '${Platform.pathSeparator}videos');
      await videoDir.create(recursive: true);

      // —— 流式哈希 + 流式复制（先临时文件，腾位后改名落位）——
      // FNV-1a 32 位采样：首 1MB 全量累入 + 之后每 64 字节采样一点，
      // 大文件不整读内存；碰撞概率与现有照片哈希同级，去重足够。
      final tmpFile = File('${videoDir.path}${Platform.pathSeparator}'
          'tmp_${DateTime.now().microsecondsSinceEpoch}$ext');
      int hash = 0x811C9DC5;
      int bytesSeen = 0;
      final sink = tmpFile.openWrite();
      await for (final chunk in src.openRead()) {
        bytesSeen += chunk.length;
        final step = bytesSeen <= 1 << 20 ? 1 : (chunk.length ~/ 64 + 1);
        int h = hash;
        for (var i = 0; i < chunk.length; i += step) {
          h = ((h ^ chunk[i]) * 0x01000193) & 0xFFFFFFFF;
        }
        hash = h;
        sink.add(chunk); // IOSink 自带缓冲，流水拷贝不逐块等待
      }
      await sink.flush();
      await sink.close();

      final name = 'v_${hash.toRadixString(16).padLeft(8, '0')}$ext';
      final rel = 'pics/videos/$name';

      final finalFile = File('${videoDir.path}${Platform.pathSeparator}$name');
      if (await finalFile.exists()) {
        // 同内容已存在（历史插入）：直接复用现有文件，删除临时件
        try {
          await tmpFile.delete();
        } catch (_) {}
      } else {
        await tmpFile.rename(finalFile.path);
      }

      // —— 时长 + 首帧缩略（ffmpeg 未就绪 → 占位兜底，不阻塞插入）——
      final durationMs = await FFmpegRunner.probeDurationMs(finalFile.path);
      final frameBytes = durationMs != null
          ? await FFmpegRunner.extractFirstFrame(finalFile.path)
          : null;
      String thumbRel = '';
      if (frameBytes != null) {
        thumbRel = await _makeThumb(frameBytes);
      }

      final st = await src.stat();
      final item = WallPhoto(
        id: newId('wv'),
        kind: 'video',
        durationMs: durationMs ?? 0,
        file: rel,
        thumb: thumbRel,
        takenAt: st.modified,
        name: srcPath
            .split(Platform.pathSeparator)
            .last
            .replaceAll(RegExp(r'\.[^.]+$'), ''),
      );
      return (VideoMaterial(item, rel), null);
    } catch (e) {
      return (null, '$e');
    }
  }

  /// 视频原件是否已入过账本/攻略（按内容文件名命中）
  static bool alreadyInLedger(Iterable<WallPhoto> ledger, String rel) =>
      ledger.any((w) => w.file == rel);

  static String _extOf(String path) {
    final base = path.split(Platform.pathSeparator).last;
    final i = base.lastIndexOf('.');
    return i > 0 ? base.substring(i).toLowerCase() : '.mp4';
  }

  /// 首帧字节 → ≤512px JPEG 缩略（与照片规格一致）
  static Future<String> _makeThumb(Uint8List jpg) async {
    try {
      final decoded = img.decodeImage(jpg);
      if (decoded == null) return '';
      final longest =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      var out = decoded;
      if (longest > 512) {
        final scale = 512 / longest;
        out = img.copyResize(
          decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      final outJpg = img.encodeJpg(out, quality: 82);
      return await MediaStore.saveVideoThumb(Uint8List.fromList(outJpg));
    } catch (_) {
      return '';
    }
  }
}
