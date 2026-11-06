import '../core/io/storage_adapter.dart';
import '../data/models/guide.dart';
import '../data/repos/guide_repository.dart';
import '../data/repos/wall_photo_repository.dart';
import '../data/models/wall_photo.dart';
import 'ffmpeg_runner.dart';
import 'media_store.dart';

/// 视频首帧缩略补齐：
/// 启动装配阶段扫描相册账本 + 各攻略内的视频条目，
/// 对缺缩略（thumb 为空）者用 ffmpeg 提取首帧 → ≤512px JPEG →
/// 复用 saveVideoThumb 内容哈希数据 → 回写记录/攻略 JSON。
/// 全部完成后不再产生 IO；ffmpeg 未就绪则本轮跳过（下次启动再试）。
///
/// 调用契约：在 main() 中 `loadAll/load` 之后、Provider 建立之前执行 ——
/// 库对象可就地修改，之后正常走仓库保存，UI 首屏即可拿到成品缩略。
class VideoThumbBackfill {
  static Future<void> run({
    required List<Guide> guides,
    required GuideRepository guideRepo,
  }) async {
    // 先显式定位 ffmpeg（available 只在探测过一次后可靠）
    await FFmpegRunner.ensure();
    if (!FFmpegRunner.available) return;
    await _backfillLedger();
    await _backfillGuides(guides, guideRepo);
  }

  // 相册账本
  static Future<void> _backfillLedger() async {
    try {
      final repo = WallPhotoRepository(activeStorage);
      final ledger = await repo.load();
      var dirty = false;
      final updated = <WallPhoto>[];
      for (final w in ledger) {
        if (!w.isVideo || w.thumb.isNotEmpty || w.file.isEmpty) {
          updated.add(w);
          continue;
        }
        final thumb = await _extractAndSave(w.file);
        if (thumb != null) {
          updated.add(w.copyWith(thumb: thumb));
          dirty = true;
        } else {
          updated.add(w);
        }
      }
      if (dirty) await repo.save(updated);
    } catch (_) {}
  }

  // 攻略内条目
  static Future<void> _backfillGuides(
      List<Guide> guides, GuideRepository guideRepo) async {
    for (final g in guides) {
      var dirty = false;
      final photos = <PhotoItem>[];
      for (final p in g.photos) {
        if (p.isVideo && p.thumb.isEmpty && p.file.isNotEmpty) {
          final thumb = await _extractAndSave(p.file);
          if (thumb != null) {
            photos.add(p.copyWith(thumb: thumb));
            dirty = true;
            continue;
          }
        }
        photos.add(p);
      }
      if (dirty) {
        try {
          await guideRepo.save(g.copyWith(photos: photos));
          g.photos // 保留对象引用就地刷新，供启动首屏使用
            ..clear()
            ..addAll(photos);
        } catch (_) {}
      }
    }
  }

  /// 提取首帧 → 形成缩略图；失败返回 null（下次启动再试）
  static Future<String?> _extractAndSave(String videoRel) async {
    try {
      final abs = activeStorage.absolutePath(videoRel);
      final bytes = await FFmpegRunner.extractFirstFrame(abs);
      if (bytes == null) return null;
      return await MediaStore.saveVideoThumb(bytes);
    } catch (_) {
      return null;
    }
  }
}
